%{
title: "Writing Elixir for AI Agents: Patterns That Help (and Hurt)",
category: "Programming",
tags: ["elixir", "ai", "coding-patterns", "best-practices", "developer-tools"],
description: "Code patterns that maximize AI agent success—and the anti-patterns that confuse them",
published: false
}
---

Last week I watched Claude spend forty-five minutes failing to understand a Phoenix context module. Not because the code was wrong—it worked fine. The agent kept hallucinating functions that didn't exist, missing pattern matches that were right there in the file, generating solutions for a different problem entirely.

The module was 847 lines. It used macros to generate CRUD operations. State lived in a process dictionary. Nothing was typed.

The code worked. The agent couldn't read it.

## The Ground Rules

AI agents don't understand code the way you do. They predict tokens. They look for patterns they've seen before; they match structure against training data; they infer intent from naming, shape, and context. Your IDE sees syntax. An agent sees probability distributions.

This has implications.

When you write `def handle_call({:get, id}, _from, state)`, an agent recognizes this pattern from tens of thousands of GenServer examples in its training set. The structure is familiar; the intent is obvious; the next tokens are predictable. It knows what you're doing.

When you write a 200-line macro that generates callbacks at compile time, the agent has fewer reference points. The transformation happens before the code exists in a readable form; the agent can't trace the data flow; it's guessing.

Here's a useful mental model: write code as if your future collaborator has read a lot of Elixir but has never seen your codebase. That collaborator will be an AI agent more often than not. Probably already is.

## Patterns That Help

### Small Pure Functions

```elixir
defmodule Payments.Calculator do
  @spec calculate_total(list(Money.t()), Decimal.t()) :: Money.t()
  def calculate_total(line_items, tax_rate) do
    line_items
    |> Enum.map(&Money.amount/1)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    |> apply_tax(tax_rate)
  end

  defp apply_tax(subtotal, rate) do
    tax = Decimal.mult(subtotal, rate)
    Decimal.add(subtotal, tax)
  end
end
```

An agent can reason about this in isolation. Inputs go in; output comes out; no side effects to track; no hidden state to consider. The function signature tells you exactly what types are expected. The pipeline shows data flowing in one direction.

Contrast this with a function that reads from the process dictionary, calls an external API, writes to a database, and returns a tuple where the meaning of each element depends on runtime configuration. An agent can generate something that compiles; it probably won't generate something that works.

Pure functions are testable in isolation, composable without surprises, and readable without context. These are exactly the properties that make code agent-friendly.

### Explicit Pattern Matching

Pattern matching makes states visible. This matters more than you might think.

```elixir
defmodule Orders.State do
  def handle(%Order{status: :pending} = order, :confirm) do
    {:ok, %{order | status: :confirmed, confirmed_at: DateTime.utc_now()}}
  end

  def handle(%Order{status: :confirmed} = order, :ship) do
    {:ok, %{order | status: :shipped, shipped_at: DateTime.utc_now()}}
  end

  def handle(%Order{status: :shipped}, :confirm) do
    {:error, :already_shipped}
  end

  def handle(%Order{status: status}, action) do
    {:error, {:invalid_transition, from: status, action: action}}
  end
end
```

Every possible state transition is enumerated. An agent reading this code knows exactly which states exist, which transitions are valid, and what happens when you try an invalid transition. The domain logic is encoded in the pattern matches themselves.

Now imagine the alternative: a single function with nested conditionals checking `order.status` in if-else chains, maybe with some early returns, possibly with state derived from multiple fields in ways that aren't obvious from the structure. Same logic, different legibility.

The pattern-matching version is longer. It's also dramatically easier for an agent to work with; it can match the structure against similar patterns it's seen; it can enumerate cases without executing code; it can generate new clauses that fit the existing shape.

### Pipeline-Heavy Code

Pipelines make data flow obvious.

```elixir
def process_webhook(payload) do
  payload
  |> Jason.decode!()
  |> validate_signature()
  |> extract_event()
  |> normalize_event()
  |> dispatch_to_handler()
  |> persist_result()
end
```

You can read this top to bottom. Data enters at the top; transforms happen in sequence; result emerges at the bottom. An agent can predict what `normalize_event/1` probably does based on its position in the pipeline and its name. It can infer types at each stage based on context.

Pipelines also constrain the solution space. When you ask an agent to add a step between `extract_event` and `normalize_event`, the insertion point is obvious; the expected input type is the output of `extract_event`; the expected output type is whatever `normalize_event` accepts. The structure guides the solution.

### Typed Structs with @enforce_keys

Here's the difference between code an agent can work with and code that leads to hallucinated fields:

```elixir
# Good: explicit, constrained, self-documenting
defmodule User do
  @enforce_keys [:id, :email]
  defstruct [:id, :email, :name, :role, :inserted_at]

  @type t :: %__MODULE__{
    id: pos_integer(),
    email: String.t(),
    name: String.t() | nil,
    role: :admin | :member | :guest,
    inserted_at: DateTime.t()
  }
end

# Bad: anything goes, nothing is documented
defmodule User do
  defstruct [:id, :email, :name, :role, :inserted_at]
end
```

The first version tells an agent: these fields exist; these types are expected; `:id` and `:email` are required; `:role` is one of three atoms. The agent can generate code that creates valid `User` structs without guessing.

The second version? An agent might generate `%User{username: "alice"}` because it's seen that field on user structs before. It might pass a string for `:role` because nothing says it shouldn't. It might omit `:id` because nothing enforces presence.

`@enforce_keys` is compile-time documentation that also happens to prevent bugs. `@type` specifications are documentation that agents can parse. Use both.

### ExDoc Examples That Actually Run

This pattern is underrated:

```elixir
defmodule Money do
  @doc """
  Adds two money values of the same currency.

  ## Examples

      iex> Money.add(Money.new(100, :USD), Money.new(50, :USD))
      {:ok, %Money{amount: 150, currency: :USD}}

      iex> Money.add(Money.new(100, :USD), Money.new(50, :EUR))
      {:error, :currency_mismatch}

  """
  @spec add(t(), t()) :: {:ok, t()} | {:error, :currency_mismatch}
  def add(%Money{currency: c} = a, %Money{currency: c} = b) do
    {:ok, %Money{amount: a.amount + b.amount, currency: c}}
  end
  def add(_, _), do: {:error, :currency_mismatch}
end
```

Those `iex>` examples aren't just documentation—they're runnable specifications that `mix test --doctest` can verify. An agent can read those examples and understand: this function takes two Money structs; it returns a tuple; success includes the result; failure returns an error atom.

More importantly, the examples show edge cases. Currency mismatch returns an error, not an exception. That's a design decision encoded in the documentation. An agent using this function will handle the error case because it saw the example.

## Patterns That Hurt

### Dynamic Module Generation

```elixir
# This is extremely hard for agents to reason about
defmacro generate_crud(schema) do
  quote do
    def list do
      Repo.all(unquote(schema))
    end

    def get(id) do
      Repo.get(unquote(schema), id)
    end

    def create(attrs) do
      unquote(schema)
      |> struct()
      |> unquote(schema).changeset(attrs)
      |> Repo.insert()
    end
  end
end
```

When you `use MyApp.Schema, schema: User`, the `list/0`, `get/1`, and `create/1` functions don't exist in any file an agent can read. They're generated at compile time from a macro that might be three modules away. The agent can't jump to definition; it can't see the implementation; it has to infer behavior from the macro source—which requires understanding quote/unquote semantics, the caller's context, and compile-time evaluation.

Most agents will fail. They'll generate code that calls functions with the wrong arity, or miss that the macro injects additional behavior, or not realize the function exists at all.

Metaprogramming has legitimate uses. Code generation for DSLs, compile-time optimization, protocol implementations—all valid. But if you're using macros to save typing, you're trading human convenience for agent confusion. Explicit code is tedious to write; it's dramatically easier to maintain, reason about, and extend with AI assistance.

### Deeply Nested Data Without Types

```elixir
# Nightmare for agents
def process(data) do
  result = data["response"]["data"]["items"]
  |> Enum.map(fn item ->
    %{
      id: item["id"],
      attrs: item["attributes"]["user"]["profile"]
    }
  end)

  {:ok, result}
end
```

What is `data`? What shape does `"response"` have? What happens when `"items"` is nil? An agent reading this function has no idea. It might assume `data` is a map; it might guess at field names; it might generate code that accesses `data["response"]["results"]` because it saw that pattern somewhere else.

The fix is typing and validation:

```elixir
@type api_response :: %{
  String.t() => %{
    "data" => %{
      "items" => list(item())
    }
  }
}

@type item :: %{
  "id" => String.t(),
  "attributes" => %{
    "user" => %{
      "profile" => map()
    }
  }
}

@spec process(api_response()) :: {:ok, list(map())}
def process(data) do
  # Now an agent knows what to expect
end
```

Better yet, parse external data into typed structs at system boundaries. Let the untyped chaos stay at the edge; work with known structures internally.

### God Contexts

Phoenix contexts are supposed to be boundaries around related functionality. I've seen contexts with 3,000 lines, 47 public functions, and dependencies on six other contexts.

An agent asked to "add a feature to the Accounts context" has to load thousands of lines of code into its context window. Token limits matter; past a certain size, the agent literally can't see the whole module at once. It has to chunk, summarize, and reconstruct—losing nuance at every step.

Large contexts also mean more surface area for hallucination. An agent might conflate `get_user/1` with `get_user!/1` or forget that `list_active_users/0` exists and write its own query. The more functions in a module, the more likely an agent is to get confused about what's available.

Split contexts by capability, not by noun. `Accounts.Registration`, `Accounts.Authentication`, `Accounts.Profile`. Smaller modules with focused responsibilities are easier for agents and humans alike.

### Process Dictionary Abuse

```elixir
# Please don't do this
def set_current_user(user) do
  Process.put(:current_user, user)
end

def current_user do
  Process.get(:current_user)
end

def some_business_logic(data) do
  user = current_user()  # Where does this come from? Who knows.
  # ...
end
```

Process dictionaries are mutable global state scoped to a process. An agent seeing `current_user()` in the middle of a function has no way to know what value it returns without tracing the entire request lifecycle. It can't tell from the function signature; it can't tell from the caller; the data appears from nowhere.

Make dependencies explicit:

```elixir
def some_business_logic(data, %User{} = user) do
  # Now an agent knows exactly what user is available and where it came from
end
```

The pattern isn't just about agent comprehension—it's about correctness. Implicit state is implicit bugs. But it's particularly bad for agents because they can't trace the runtime flow; they see code statically; hidden state is invisible state.

## Naming for Machines

Function names are training signal.

An agent has seen `get_user_by_id/1` thousands of times. It knows this function takes an ID, queries a user table, returns a user or nil. The name pattern is so consistent across the Elixir ecosystem that an agent can predict behavior before reading the implementation.

Compare to `fetch_u/1`. Fetch what? What's `u`? Is this different from `get`? An agent has to read the implementation to understand—and even then, it might not retain the distinction when generating code elsewhere in the codebase.

**Use consistent verb prefixes:**
- `get_*` — returns value or nil
- `get_*!` — returns value or raises
- `fetch_*` — returns `{:ok, value}` or `{:error, reason}`
- `list_*` — returns enumerable
- `create_*`, `update_*`, `delete_*` — write operations
- `maybe_*` — conditional operation, might return nil
- `ensure_*` — validates or creates, always succeeds or raises

**Avoid abbreviations.** `calculate_subscription_renewal_date/1` is longer than `calc_sub_rnwl_dt/1`; it's also comprehensible. Agents have unlimited patience for long names; they don't have training data for your personal abbreviation system.

**Be specific.** `process_data/1` tells an agent nothing. `validate_webhook_signature/1` tells an agent everything it needs to call the function correctly.

## Testing as Specification

Tests are the highest-signal documentation for AI agents. They show intent, inputs, outputs, and edge cases—all in executable form.

```elixir
describe "calculate_shipping/2" do
  test "returns free shipping for orders over $100" do
    order = build(:order, total: Money.new(15000, :USD))

    assert {:ok, %Shipping{cost: cost}} = calculate_shipping(order, :standard)
    assert Money.zero?(cost)
  end

  test "charges $9.99 for standard shipping under $100" do
    order = build(:order, total: Money.new(5000, :USD))

    assert {:ok, %Shipping{cost: cost}} = calculate_shipping(order, :standard)
    assert Money.equals?(cost, Money.new(999, :USD))
  end

  test "returns error for unsupported destinations" do
    order = build(:order, destination: :antarctica)

    assert {:error, :unsupported_destination} = calculate_shipping(order, :standard)
  end
end
```

An agent reading these tests learns: free shipping threshold is $100; standard shipping is $9.99; certain destinations aren't supported; the function returns ok/error tuples. This is specification by example—and agents are excellent at learning from examples.

Property-based tests are even better:

```elixir
property "shipping cost is never negative" do
  check all order <- order_generator(),
            method <- member_of([:standard, :express, :overnight]) do
    case calculate_shipping(order, method) do
      {:ok, %Shipping{cost: cost}} -> assert Money.positive?(cost) or Money.zero?(cost)
      {:error, _} -> :ok
    end
  end
end
```

This tells an agent something no example-based test can: the invariant holds for all inputs. When generating code that uses `calculate_shipping`, an agent knows it can assume non-negative costs without checking individual cases.

## The Uncomfortable Reality

I've been writing Elixir for years; I'm now writing Elixir for AI agents. They're not the same skill.

The patterns that make you feel clever—complex macros, implicit state, terse naming—are the patterns that make agents fail. The patterns that feel tedious—explicit types, verbose names, small modules—are the patterns that make agents succeed.

This isn't about dumbing down code. The best agent-friendly patterns are also the best human-friendly patterns; they just happen to be patterns we often skip in the name of convenience or cleverness.

I don't know where this goes. As agents improve, maybe they'll handle metaprogramming better; maybe they'll trace process dictionary state; maybe they'll infer types from runtime behavior. Or maybe explicit code will always beat implicit code for machine comprehension, the same way it beats implicit code for human comprehension across large teams.

What I do know: the code I write today will be maintained by agents tomorrow. I'm starting to write accordingly.
