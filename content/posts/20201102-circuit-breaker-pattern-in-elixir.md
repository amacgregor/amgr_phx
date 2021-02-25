%{
    title: "Circuit Breaker Pattern in Elixir",
    category: "Programming",
    tags: ["elixir", "functional programming", "design patterns"], 
  description: 'Design for failure with the circuit breaker pattern'
  }
---

<!--Design for failure with the circuit breaker pattern-->

> A circuit breaker is used to detect failures and to encapsulate the logic of preventing a failure from constantly recurring during maintenance, temporary external system failure, or unexpected system difficulties.

In the age of microservices, we are more than likely to have services that are calling and dependent on external services outside of our control.

Remote services can hang, fail or become unresponsive. How can we prevent those failures from cascading through the system and from taking up critical resources?

Enter the **Circuit breaker** pattern. The pattern was popularized in the book Release It by Michael Nygard, and by thought leaders like [Martin Fowler](https://martinfowler.com/bliki/CircuitBreaker.html).

![Circuit Breaker Pattern](/images/posts/circuit_breaker_diagram.png)

The idea behind this pattern is very simple: **Failures are inevitable, and trying to prevent them altogether is not realistic**.

A way to handle these failures is by wrapping these operations into some kind of proxy. This proxy is responsible for monitoring recent failures, and using this information to decide whether to allow the operation to proceed or return an early failure instead.

This proxy is typically implemented as a state machine that mimics the functionality of a physical **circuit breaker** which my have 3 states:

- **Closed:** In this state the circuit breaker lets all the requests go through while keeping track of the number of recent failures, and if the number of failures exceeds a specific threshold within a specific time frame, it will switch to the **Open** state.
- **Open:** In this state, any requests are not sent to the external service. Instead we either fail immediately returning an extension, or fall back to a secondary system like a cache.
- **Half-Open:** In this state, a limited number of requests from the application are allowed to pass-through and call our external service. Depending on the result of these requests the **circuit breaker** will either flip to a Closed state or go back to the Open state resetting the counter before trying to open again.

The Circuit Breaker pattern offers a few key advantages worth noting:

- The **Half-Open** state gives the external system time to recover without getting flooded.
- The **Open** state implementation gives options for how we want to handle failure, whether failing right away or falling back to a caching layer or secondary system.
- This pattern can also be leveraged to help to maintain response times by **quickly rejecting calls** that are likely to fail or timeout.

## Example

For our example, let's imagine that we have the following scenario:

> We are running a job board aggregator that will consume job postings from Github and other sources. However, since we are consuming a few different APIs we run the risk that we will hit a request limit or that an API will be down.

<!-- Scenario -->

Let's start by creating an example API connector to **Github Jobs** that retrieves the latest 50 jobs posted:

```elixir
defmodule CircuitBreaker.Api.GithubJobs do
    ...
    @spec get_positions :: none
    def get_positions do
        case HTTPoison.get(url()) do
        {:ok, response} -> {:ok, parse_fields(response.body)}
        {:error, %HTTPoison.Error{id: _, reason: reason}} -> {:error, reason}
        end
    end
    ...
end
```

**file**: [lib/circuit_breaker/api/github_jobs.ex](https://github.com/amacgregor/circuit_breaker_example/blob/main/lib/circuit_breaker/api/github_jobs.ex)

All this connector is doing is making a request to `jobs.github.com` retrieving the JSON, parsing it, and returning the list of jobs. If we want to test this we can manually call `get_positions` in our console:

```elixir
iex(1)> CircuitBreaker.Api.GithubJobs.get_positions
{:ok,
 ["Software Engineer", "Backend Engineer (w/m/d)",
  "Senior Frontend Engineer (f/m/d)", ...]}
```

### Circuit Breaker Switch

Now that we have ability to make calls to get the job postings, we need to build our circuit breaker to wrap around the API adapter. Let's take a look at a skeleton for our switch.

```elixir
defmodule CircuitBreaker.Api.Switch do
  use GenStateMachine, callback_mode: :state_functions

  @name :circuit_breaker_switch
  @error_count_limit 8
  @time_to_half_open_delay 8000

  def start_link do
    GenStateMachine.start_link(__MODULE__, {:closed, %{error_count: 0}}, name: @name)
  end

  def get_positions do
    GenStateMachine.call(@name, :get_positions)
  end
  ...
end
```

**file**: [lib/circuit_breaker/api/switch.ex](https://github.com/amacgregor/circuit_breaker_example/blob/main/lib/circuit_breaker/api/switch.ex)

For implementing our circuit breaker we could use the `gen_statem` behavior directly or in this case leverage the **GenStateMachine** package which gives us tracking and error reporting, and will work with the supervision tree.

The first two functions we added are:

- `start_link`: will start the circuit breaker with an initial state and a specific name.
- `get_positions`: this is our public client API that wraps around the **Github Jobs** adapter we just built.

An important thing to note here is the first line:

```elixir
  use GenStateMachine, callback_mode: :state_functions
```

In this callback mode, every time you do a `call/3` or a `cast/2`, the message will be handled by the `state_name/3` function which is named the same as the current state. In this case our state_name functions will be `open`, `closed`, `half_open`.

Let's go ahead and start by adding our closed state code:

```elixir
  def closed({:call, from}, :get_positions, data) do
    case CircuitBreaker.Api.GithubJobs.get_positions() do
      {:ok, positions} ->
        {:keep_state, %{error_count: 0}, {:reply, from, {:ok, positions}}}
      {:error, reason} ->
        handle_error(reason, from, %{ data | error_count: data.error_count + 1 })
    end
  end
```

**file**: [lib/circuit_breaker/api/switch.ex](https://github.com/amacgregor/circuit_breaker_example/blob/main/lib/circuit_breaker/api/switch.ex)

All we are doing is calling the API adapter **get_positions** and, depending on the results, we are either returning the positions list or handling the error.

Let's go ahead and jump into the terminal and **try to get the list of positions** through our circuit breaker:

```elixir
iex(1)> CircuitBreaker.Api.Switch.start_link
{:ok, #PID<0.231.0>}
iex(2)> CircuitBreaker.Api.Switch.get_positions
{:ok,
 ["Software Engineer", "Backend Engineer (w/m/d)",
  "Senior Frontend Engineer (f/m/d)", ...]}
```

Let's add the function for the other two states and review how the circuit state change works.

```elixir
  def half_open({:call, from}, :get_positions, data) do
    case CircuitBreaker.Api.GithubJobs.get_positions() do
      {:ok, positions} ->
        {:next_state, :closed, %{count_error: 0}, {:reply, from, {:ok, positions}}}
      {:error, reason} ->
        open_circuit(from, data, reason, @time_to_half_open_delay)
    end
  end

  def open({:call, from}, :get_positions, data) do
    {:keep_state, data, {:reply, from, {:error, :circuit_open}}}
  end

  def open(:info, :to_half_open, data) do
    {:next_state, :half_open, data}
  end
```

And let's add a couple of private utility functions:

```elixir
  defp handle_error(reason, from, data = %{error_count: error_count}) when error_count > @error_count_limit do
      open_circuit(from, data, reason, @time_to_half_open_delay)
  end

  defp handle_error(reason, from, data) do
    {:keep_state, data, {:reply, from, {:error, reason}}}
  end

  defp open_circuit(from, data, reason, delay) do
    Process.send_after(@name, :to_half_open, delay)
    {:next_state, :open, data, {:reply, from, {:error, reason}}}
  end
```

Most of the magic is happening in the `open_circuit` function where we are doing two things:

- First, we schedule a message to set our circuit breaker state to `half_open` after our specified delay.
- Second, we return a new state setting the circuit breaker fully `open`.

After **8000 milliseconds**, the circuit breaker, now in the open state, will receive our scheduled message and change the state to **half_open**.

Finally, during **half_open** state, we will try to make the calls to the API endpoint, and in case of failure we will switch automatically back to fully **open** and try again.

## Conclusions

**Circuit Breakers** are a valuable pattern to have in our arsenal, as they can help increase system stability and have a more reliable way of handling errors with remote services.

This example just scratched the surface of what you can do with circuit breakers. There are plenty of opportunities to expand this pattern further, such as:

- Improve the logic for tripping the breaker by also looking at the type of errors, and frequency.
- Add monitoring and logging once the circuit breaker changes state.
- Fallback to a secondary service or cache layer before returning the failure.

Finally, as with any pattern, it is important to keep in mind the use case and decided if this kind of behavior is desired.

The full code for this example can be found in [circuit_breaker_example](https://github.com/amacgregor/circuit_breaker_example)

### Further Reading

- [Microsoft - Circuit Breaker pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
- [Martin Fowler](https://netflixtechblog.com/fault-tolerance-in-a-high-volume-distributed-system-91ab4faae74a)
- [Microservice Architecture - Circuit Breaker Pattern](https://microservices.io/patterns/reliability/circuit-breaker.html)
