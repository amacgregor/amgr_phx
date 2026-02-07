%{
title: "GenServer Patterns You Should Know",
category: "Programming",
tags: ["elixir", "otp", "genserver", "patterns"],
description: "Beyond the basics: practical GenServer patterns from production systems",
published: false
}

---

Most Elixir tutorials teach you how to start a GenServer. They show you the callbacks, explain the difference between `handle_call` and `handle_cast`, and send you on your way. Then you hit production, and you realize that knowing the API is not the same as knowing when and how to use it.

This is not a GenServer tutorial. This is a field guide to the patterns that separate functioning code from production-ready systems.

## The Thirty-Second GenServer Refresher

A GenServer is a process that holds state and responds to messages. It implements the `GenServer` behaviour, which gives you three core callbacks: `handle_call` for synchronous requests, `handle_cast` for asynchronous fire-and-forget messages, and `handle_info` for everything else.

```elixir
defmodule Counter do
  use GenServer

  def start_link(initial), do: GenServer.start_link(__MODULE__, initial)

  def increment(pid), do: GenServer.call(pid, :increment)

  @impl true
  def init(count), do: {:ok, count}

  @impl true
  def handle_call(:increment, _from, count), do: {:reply, count + 1, count + 1}
end
```

If this looks unfamiliar, stop here and read the official docs first. What follows assumes you know the mechanics.

## Call vs Cast: The Backpressure Decision

The choice between `call` and `cast` is not about synchronous versus asynchronous. It is about backpressure.

When you use `GenServer.call/2`, the caller blocks until the server responds. This creates natural backpressure. If your server cannot keep up with demand, callers slow down. The system self-regulates.

When you use `GenServer.cast/2`, the caller fires a message and moves on. Messages pile up in the server's mailbox. If production traffic spikes and your server processes messages slower than they arrive, that mailbox grows without bound. Eventually, you run out of memory.

```elixir
# This creates backpressure - caller waits for acknowledgment
def write_to_database(pid, record) do
  GenServer.call(pid, {:write, record})
end

# This does not - messages can pile up indefinitely
def log_event(pid, event) do
  GenServer.cast(pid, {:log, event})
end
```

I use `cast` in exactly two scenarios. First, when I genuinely do not care if the operation succeeds, the caller has no use for the result, and losing messages under extreme load is acceptable. Telemetry events often fall into this category. Second, when I have implemented explicit backpressure elsewhere, such as a bounded queue or rate limiter upstream.

For everything else, I default to `call`. The 5-second default timeout is a feature, not a bug. It tells you when your system is overwhelmed.

One pattern I have found useful in high-throughput systems is the "call with cast semantics" approach:

```elixir
def enqueue(pid, item) do
  # Still blocks, but returns immediately after the server receives the message
  # The actual work happens asynchronously
  GenServer.call(pid, {:enqueue, item})
end

@impl true
def handle_call({:enqueue, item}, _from, state) do
  new_state = add_to_queue(state, item)
  {:reply, :ok, new_state}
end
```

The caller blocks just long enough to confirm the message was received and queued. The expensive work happens later. You get backpressure without blocking on the slow operation.

## handle_continue: Async Initialization Done Right

Before Elixir 1.7, initializing a GenServer with slow operations was awkward. You had two bad options: block in `init/1` and delay the supervisor, or `send(self(), :init)` and handle it in `handle_info/2`.

The `send` approach had a subtle race condition. If a client called your GenServer between `init/1` returning and your `handle_info(:init)` running, they would hit an uninitialized server.

`handle_continue` solves this cleanly:

```elixir
defmodule DatabasePool do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # Return immediately so supervisor can continue
    # But the process is not "ready" until handle_continue completes
    {:ok, %{opts: opts, connections: []}, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    # This runs before any handle_call or handle_cast
    connections = Enum.map(1..state.opts[:pool_size], fn _ ->
      {:ok, conn} = Database.connect(state.opts[:config])
      conn
    end)
    {:noreply, %{state | connections: connections}}
  end

  @impl true
  def handle_call(:get_connection, _from, %{connections: []} = state) do
    # No connections available yet or pool exhausted
    {:reply, {:error, :no_connections}, state}
  end

  def handle_call(:get_connection, _from, %{connections: [conn | rest]} = state) do
    {:reply, {:ok, conn}, %{state | connections: rest}}
  end
end
```

The key insight: `handle_continue` runs before any external messages are processed. Your GenServer is fully initialized before it handles its first call. No race conditions.

I also use `handle_continue` for chaining initialization steps:

```elixir
def handle_continue(:load_config, state) do
  config = load_config_from_disk()
  {:noreply, %{state | config: config}, {:continue, :validate_config}}
end

def handle_continue(:validate_config, state) do
  :ok = validate_config(state.config)
  {:noreply, %{state | status: :ready}, {:continue, :notify_ready}}
end

def handle_continue(:notify_ready, state) do
  Phoenix.PubSub.broadcast(MyApp.PubSub, "system", {:service_ready, __MODULE__})
  {:noreply, state}
end
```

Each step is explicit. The chain of operations is visible in the code. Debugging initialization issues becomes straightforward.

## State Machines with GenServer

GenServer is a natural fit for state machines. The state tuple already exists. You just need to make transitions explicit.

Here is a pattern I use for processes with distinct operational modes:

```elixir
defmodule OrderProcessor do
  use GenServer

  # States: :idle, :processing, :awaiting_payment, :completed, :failed

  def start_link(order_id) do
    GenServer.start_link(__MODULE__, order_id)
  end

  @impl true
  def init(order_id) do
    {:ok, %{order_id: order_id, status: :idle, data: nil}}
  end

  @impl true
  def handle_call(:start_processing, _from, %{status: :idle} = state) do
    case fetch_order(state.order_id) do
      {:ok, order} ->
        {:reply, :ok, %{state | status: :processing, data: order}}
      {:error, reason} ->
        {:reply, {:error, reason}, %{state | status: :failed}}
    end
  end

  def handle_call(:start_processing, _from, %{status: status} = state) do
    {:reply, {:error, {:invalid_transition, :idle, status}}, state}
  end

  def handle_call(:request_payment, _from, %{status: :processing} = state) do
    case PaymentGateway.authorize(state.data) do
      {:ok, payment_ref} ->
        new_state = %{state | status: :awaiting_payment, data: Map.put(state.data, :payment_ref, payment_ref)}
        {:reply, {:ok, payment_ref}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, %{state | status: :failed}}
    end
  end

  def handle_call(:request_payment, _from, %{status: status} = state) do
    {:reply, {:error, {:invalid_transition, :processing, status}}, state}
  end

  def handle_call(:confirm_payment, _from, %{status: :awaiting_payment} = state) do
    case PaymentGateway.capture(state.data.payment_ref) do
      :ok ->
        {:reply, :ok, %{state | status: :completed}}
      {:error, reason} ->
        {:reply, {:error, reason}, %{state | status: :failed}}
    end
  end

  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end
end
```

The pattern matching on `%{status: :some_state}` makes invalid transitions impossible. The compiler does not enforce this, but the runtime does. Every transition is explicit.

For more complex state machines, I extract the transition logic:

```elixir
defp transition(%{status: :idle}, :start) do
  {:ok, :processing}
end

defp transition(%{status: :processing}, :payment_requested) do
  {:ok, :awaiting_payment}
end

defp transition(%{status: :awaiting_payment}, :payment_confirmed) do
  {:ok, :completed}
end

defp transition(%{status: from}, event) do
  {:error, {:invalid_transition, from, event}}
end
```

Now your state machine logic lives in pure functions. Easy to test. Easy to reason about.

## Timeouts and Periodic Work

GenServer supports timeouts natively. Return a timeout from any callback, and if no message arrives within that window, you receive a `:timeout` message:

```elixir
defmodule CacheWarmer do
  use GenServer

  @refresh_interval :timer.minutes(5)

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Warm cache immediately on start
    {:ok, %{cache: warm_cache()}, @refresh_interval}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:noreply, %{state | cache: warm_cache()}, @refresh_interval}
  end

  @impl true
  def handle_call(:get, _from, state) do
    # Reset timeout after each call
    {:reply, state.cache, state, @refresh_interval}
  end

  defp warm_cache do
    # Expensive operation to populate cache
    Database.fetch_all_products()
  end
end
```

The timeout approach has one gotcha: the timer resets whenever the process receives any message. If your GenServer handles frequent calls, the timeout might never fire.

For reliable periodic work, use `Process.send_after/3` or `:timer.send_interval/2`:

```elixir
defmodule MetricsCollector do
  use GenServer

  @collect_interval :timer.seconds(10)

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    schedule_collection()
    {:ok, %{metrics: []}}
  end

  @impl true
  def handle_info(:collect, state) do
    metrics = collect_current_metrics()
    schedule_collection()
    {:noreply, %{state | metrics: [metrics | state.metrics]}}
  end

  defp schedule_collection do
    Process.send_after(self(), :collect, @collect_interval)
  end

  defp collect_current_metrics do
    %{
      memory: :erlang.memory(:total),
      process_count: :erlang.system_info(:process_count),
      timestamp: System.monotonic_time(:millisecond)
    }
  end
end
```

This pattern guarantees your periodic work runs regardless of other message traffic. The interval is measured from when you schedule, not from when the previous work completed, so consider using `Process.send_after/3` at the end of your work if you want a consistent gap between executions.

## Testing GenServers Effectively

Testing GenServers requires thinking about process boundaries. Here are patterns that work.

For synchronous testing, start the GenServer in your test and interact with it directly:

```elixir
defmodule CounterTest do
  use ExUnit.Case, async: true

  test "increments the count" do
    {:ok, pid} = Counter.start_link(0)

    assert Counter.increment(pid) == 1
    assert Counter.increment(pid) == 2
  end

  test "starts with initial value" do
    {:ok, pid} = Counter.start_link(42)

    assert Counter.get(pid) == 42
  end
end
```

For GenServers with external dependencies, inject them:

```elixir
defmodule NotificationSender do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    # Allow injecting a mock notifier for tests
    notifier = Keyword.get(opts, :notifier, RealNotifier)
    {:ok, %{notifier: notifier, pending: []}}
  end

  @impl true
  def handle_call({:send, message}, _from, state) do
    result = state.notifier.send(message)
    {:reply, result, state}
  end
end

# In tests:
defmodule NotificationSenderTest do
  use ExUnit.Case, async: true

  defmodule MockNotifier do
    def send(_message), do: :ok
  end

  test "sends notifications through the notifier" do
    {:ok, pid} = NotificationSender.start_link(notifier: MockNotifier)

    assert NotificationSender.send(pid, "Hello") == :ok
  end
end
```

For testing `handle_info` and timeouts, you can send messages directly:

```elixir
test "handles timeout by refreshing cache" do
  {:ok, pid} = CacheWarmer.start_link(nil)

  # Trigger the timeout handler manually
  send(pid, :timeout)

  # Give it time to process
  :timer.sleep(10)

  # Verify the cache was refreshed
  assert CacheWarmer.get(pid) != nil
end
```

For testing async behavior, use `assert_receive` with the `allow` function from Mox if you are mocking:

```elixir
test "broadcasts status changes" do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "orders")

  {:ok, pid} = OrderProcessor.start_link("order-123")
  OrderProcessor.start_processing(pid)

  assert_receive {:order_status_changed, "order-123", :processing}, 1000
end
```

## GenServer vs Agent vs Task: Choosing Your Abstraction

These three abstractions solve different problems. Choose wrong, and you either over-engineer simple cases or under-engineer complex ones.

**Agent** is a GenServer stripped down to pure state management. No custom message handling. No complex initialization. Just get and update:

```elixir
{:ok, agent} = Agent.start_link(fn -> %{} end)
Agent.update(agent, &Map.put(&1, :key, "value"))
Agent.get(agent, &Map.get(&1, :key))
```

Use Agent when you need shared mutable state and nothing else. Configuration holders. Simple caches. Counters. The moment you need custom message handling, timeouts, or complex initialization, switch to GenServer.

**Task** is for one-shot async work that produces a result:

```elixir
task = Task.async(fn -> expensive_computation() end)
result = Task.await(task)
```

Use Task when you need to run something concurrently and collect the result. Parallel HTTP requests. Background computations. Fan-out/fan-in patterns. Tasks are not for long-running processes. They do one thing and terminate.

**GenServer** is the general-purpose tool. Use it when:

- You need custom message handling beyond get/update
- You need to respond to system events (monitors, timeouts)
- Your process has complex lifecycle requirements
- You need to implement protocols or behaviors
- You are building something that will live for the duration of your application

Here is my decision tree:

1. Is this a one-shot operation that returns a result? Use Task.
2. Is this just holding state with basic get/update? Use Agent.
3. Everything else: Use GenServer.

When in doubt, start with GenServer. It is more code, but it gives you room to grow. I have never regretted starting with GenServer. I have regretted starting with Agent and having to rewrite.

## The Patterns That Matter

GenServer is not complicated. The callbacks are simple. The message passing model is straightforward. What separates working code from production code is knowing which patterns to apply and when.

Use `call` by default. Think about backpressure before you reach for `cast`. Initialize with `handle_continue`. Make your state transitions explicit. Test through the public API. And when you are unsure whether you need a GenServer, you probably do.

The BEAM gives you an incredible foundation for building concurrent systems. GenServer is how you build on that foundation without reinventing the wheel. Use it well.

---

**Claims to verify:**

- The race condition with `send(self(), :init)` before `handle_continue` existed is accurate for Elixir versions prior to 1.7
- Default `GenServer.call` timeout is 5000ms (5 seconds)
- `:timer.send_interval/2` behavior regarding timing from schedule vs completion
