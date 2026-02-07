%{
title: "Event Sourcing with Elixir",
category: "Programming",
tags: ["elixir", "event-sourcing", "architecture", "cqrs"],
description: "Building event stores, projections, and handling schema evolution in Elixir",
published: false
}
---

Most developers reach for event sourcing when they shouldn't. They read about it solving problems at scale—Kafka at LinkedIn, event-driven architectures at Netflix—and assume it will magically fix their CRUD application's complexity. It won't.

But for the right problems? Event sourcing fundamentally changes how you think about data. Instead of storing the current state of your system, you store every change that led to that state. Your database becomes a log of facts, immutable and complete. And Elixir, with its functional paradigm and pattern matching, turns out to be exceptionally well-suited for this approach.

## What Event Sourcing Actually Is

Traditional databases store state. You have a `users` table with a row for each user. When a user changes their email, you update that row. The old email is gone—overwritten, forgotten, as if it never existed.

Event sourcing inverts this model. You store events: `UserRegistered`, `EmailChanged`, `AccountSuspended`. The current state is derived by replaying these events. Want to know a user's email? Walk through every event that affected that user and compute it.

This sounds inefficient. For a single read, it is. But consider what you gain:

- **Complete audit trail.** Every change is preserved. Regulatory compliance becomes trivial.
- **Time travel.** Want to know what the system looked like on March 15th at 3 PM? Replay events up to that point.
- **Bug investigation.** Reproduce any state by replaying events up to the moment before the bug occurred.
- **Decoupled read models.** Build multiple projections optimized for different query patterns.

The trade-off is complexity. You're building a distributed system even when you don't think you are. Events need to be versioned. Projections need to be rebuilt. Snapshots need to be managed. This isn't free.

## Building an Event Store with Ecto

Let's build a minimal event store. No libraries, no frameworks—just Ecto and some thoughtful schema design.

First, the events table:

```elixir
defmodule MyApp.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :stream_id, :string, null: false
      add :stream_version, :integer, null: false
      add :event_type, :string, null: false
      add :data, :map, null: false
      add :metadata, :map, default: %{}

      timestamps(updated_at: false)
    end

    create unique_index(:events, [:stream_id, :stream_version])
    create index(:events, [:stream_id])
    create index(:events, [:event_type])
  end
end
```

The `stream_id` groups related events—typically an aggregate ID. The `stream_version` ensures ordering and enables optimistic concurrency control. That unique index? It prevents two processes from appending conflicting events to the same stream.

Now the event store module:

```elixir
defmodule MyApp.EventStore do
  alias MyApp.Repo
  alias MyApp.Events.StoredEvent
  import Ecto.Query

  def append_events(stream_id, expected_version, events) do
    Repo.transaction(fn ->
      current_version = get_stream_version(stream_id)

      if current_version != expected_version do
        Repo.rollback(:concurrency_conflict)
      end

      events
      |> Enum.with_index(expected_version + 1)
      |> Enum.each(fn {event, version} ->
        %StoredEvent{
          id: Ecto.UUID.generate(),
          stream_id: stream_id,
          stream_version: version,
          event_type: event.__struct__ |> Module.split() |> List.last(),
          data: Map.from_struct(event),
          metadata: %{correlation_id: get_correlation_id()}
        }
        |> Repo.insert!()
      end)
    end)
  end

  def read_stream(stream_id, from_version \\ 0) do
    StoredEvent
    |> where([e], e.stream_id == ^stream_id)
    |> where([e], e.stream_version > ^from_version)
    |> order_by([e], asc: e.stream_version)
    |> Repo.all()
    |> Enum.map(&deserialize_event/1)
  end

  defp get_stream_version(stream_id) do
    StoredEvent
    |> where([e], e.stream_id == ^stream_id)
    |> select([e], max(e.stream_version))
    |> Repo.one() || 0
  end

  defp deserialize_event(%StoredEvent{event_type: type, data: data}) do
    module = Module.concat([MyApp.Events, type])
    struct(module, atomize_keys(data))
  end

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  end
end
```

The `expected_version` parameter is where optimistic concurrency lives. Before appending, we verify that no other process has written to this stream since we last read it. If someone has, we fail fast rather than corrupt the event log.

## Projections: Rebuilding State from Events

Events are useless without projections. A projection is a read model—a representation of state derived by folding over events.

```elixir
defmodule MyApp.Projections.AccountBalance do
  use GenServer
  alias MyApp.EventStore

  defstruct [:account_id, balance: 0, version: 0]

  def start_link(account_id) do
    GenServer.start_link(__MODULE__, account_id, name: via_tuple(account_id))
  end

  def get_balance(account_id) do
    GenServer.call(via_tuple(account_id), :get_balance)
  end

  @impl true
  def init(account_id) do
    state = rebuild_from_events(account_id)
    schedule_sync()
    {:ok, state}
  end

  @impl true
  def handle_call(:get_balance, _from, state) do
    {:reply, state.balance, state}
  end

  @impl true
  def handle_info(:sync, state) do
    new_events = EventStore.read_stream(state.account_id, state.version)
    new_state = apply_events(state, new_events)
    schedule_sync()
    {:noreply, new_state}
  end

  defp rebuild_from_events(account_id) do
    events = EventStore.read_stream(account_id)
    apply_events(%__MODULE__{account_id: account_id}, events)
  end

  defp apply_events(state, events) do
    Enum.reduce(events, state, &apply_event/2)
  end

  defp apply_event(%{event_type: "MoneyDeposited", data: %{amount: amount}}, state) do
    %{state | balance: state.balance + amount, version: state.version + 1}
  end

  defp apply_event(%{event_type: "MoneyWithdrawn", data: %{amount: amount}}, state) do
    %{state | balance: state.balance - amount, version: state.version + 1}
  end

  defp apply_event(_unknown_event, state), do: state

  defp schedule_sync, do: Process.send_after(self(), :sync, 1000)

  defp via_tuple(account_id), do: {:via, Registry, {MyApp.Registry, account_id}}
end
```

Notice the pattern matching in `apply_event/2`. Each event type has a dedicated clause. Unknown events fall through harmlessly—forward compatibility baked in. The projection polls for new events periodically; in production you'd likely use PostgreSQL NOTIFY or a message broker for push-based updates.

## Snapshots: Taming the Replay Problem

Event streams grow. An account with ten years of transactions might have thousands of events. Replaying all of them on every read isn't practical.

Snapshots solve this. Periodically, you serialize the current state and store it alongside the events. On load, you restore from the latest snapshot and replay only subsequent events.

```elixir
defmodule MyApp.Snapshots do
  alias MyApp.Repo
  alias MyApp.Snapshots.Snapshot
  import Ecto.Query

  def save_snapshot(stream_id, version, state) do
    %Snapshot{
      stream_id: stream_id,
      version: version,
      data: :erlang.term_to_binary(state)
    }
    |> Repo.insert!(
      on_conflict: {:replace, [:version, :data, :updated_at]},
      conflict_target: :stream_id
    )
  end

  def load_snapshot(stream_id) do
    Snapshot
    |> where([s], s.stream_id == ^stream_id)
    |> Repo.one()
    |> case do
      nil -> nil
      snapshot ->
        {:ok, snapshot.version, :erlang.binary_to_term(snapshot.data)}
    end
  end
end
```

Integrating snapshots into our projection:

```elixir
defp rebuild_from_events(account_id) do
  case Snapshots.load_snapshot(account_id) do
    {:ok, version, state} ->
      events = EventStore.read_stream(account_id, version)
      apply_events(state, events)

    nil ->
      events = EventStore.read_stream(account_id)
      state = apply_events(%__MODULE__{account_id: account_id}, events)

      # Snapshot every 100 events
      if state.version >= 100 and rem(state.version, 100) == 0 do
        Snapshots.save_snapshot(account_id, state.version, state)
      end

      state
  end
end
```

The frequency of snapshotting is a tuning parameter. Too frequent, and you're wasting storage and write bandwidth. Too infrequent, and replays become slow. I've seen 100-event intervals work well for most applications, but profile your specific workload.

## Schema Evolution: The Hard Problem

Events are immutable. You can't go back and change them. But your domain model evolves. New requirements emerge. The event you designed in 2023 doesn't capture the nuance you need in 2026.

There are three primary strategies:

**Upcasting**: Transform old events to new formats at read time.

```elixir
defmodule MyApp.EventUpcasters do
  # v1 had separate first_name and last_name
  # v2 combines them into full_name
  def upcast(%{event_type: "UserRegistered", data: data, metadata: %{version: 1}}) do
    full_name = "#{data["first_name"]} #{data["last_name"]}"

    %{
      event_type: "UserRegistered",
      data: Map.put(data, "full_name", full_name),
      metadata: %{version: 2}
    }
  end

  def upcast(event), do: event
end
```

Apply upcasters when deserializing:

```elixir
defp deserialize_event(%StoredEvent{} = stored_event) do
  stored_event
  |> Map.from_struct()
  |> EventUpcasters.upcast()
  |> build_domain_event()
end
```

**Event versioning**: Include version in the event type.

```elixir
defmodule MyApp.Events.UserRegisteredV1 do
  defstruct [:user_id, :first_name, :last_name, :email]
end

defmodule MyApp.Events.UserRegisteredV2 do
  defstruct [:user_id, :full_name, :email, :marketing_consent]
end
```

**Copy-transform**: Create a new event stream with transformed events. Use this sparingly—it's operationally expensive and risks data inconsistency.

My preference is upcasting for minor changes (adding fields, renaming) and new event types for semantic shifts. If `OrderPlaced` fundamentally changes what it means, create `OrderPlacedV2` rather than pretending they're the same thing.

## Commanded: When to Use a Framework

The code above works. But once you move beyond toy examples, you'll want: command validation, aggregate lifecycle management, process managers for sagas, subscription handling, and more.

Commanded is the de facto event sourcing library for Elixir. It provides these abstractions:

```elixir
defmodule MyApp.BankAccount do
  use Commanded.Aggregates.Aggregate

  defstruct [:account_id, :balance]

  def execute(%__MODULE__{account_id: nil}, %OpenAccount{} = cmd) do
    %AccountOpened{account_id: cmd.account_id, initial_balance: 0}
  end

  def execute(%__MODULE__{balance: balance}, %WithdrawMoney{amount: amount})
      when balance >= amount do
    %MoneyWithdrawn{amount: amount}
  end

  def execute(%__MODULE__{}, %WithdrawMoney{}) do
    {:error, :insufficient_funds}
  end

  def apply(%__MODULE__{} = account, %AccountOpened{} = event) do
    %{account | account_id: event.account_id, balance: event.initial_balance}
  end

  def apply(%__MODULE__{} = account, %MoneyWithdrawn{} = event) do
    %{account | balance: account.balance - event.amount}
  end
end
```

Commanded handles concurrency, event storage, projection subscriptions, and gives you a clear aggregate pattern. The trade-off is abstraction—you're now working within Commanded's model of the world.

When to roll your own versus using Commanded:

**Roll your own** when you need maximum control, have unusual storage requirements, or when learning the underlying concepts. Building from scratch teaches you what the framework hides.

**Use Commanded** when you're building a production system, need process managers, want robust subscription handling, or your team benefits from established conventions.

I've done both. For applications where event sourcing is central to the domain—financial systems, audit-heavy workflows—Commanded's conventions pay for themselves. For simpler cases where you're adding event sourcing to specific bounded contexts, a lightweight custom implementation keeps things simple.

## When NOT to Use Event Sourcing

Event sourcing is not a default architecture. It's a specialized tool with real costs:

**Don't use it for simple CRUD.** If your domain is "user updates profile, we save it," you're adding complexity for no benefit. A regular PostgreSQL table is fine.

**Don't use it without understanding eventual consistency.** Projections lag behind writes. If your application requires read-your-writes consistency everywhere, you'll fight the model constantly.

**Don't use it for data you need to delete.** GDPR right-to-erasure doesn't play nicely with immutable event logs. Crypto-shredding (encrypting events with per-user keys, then deleting the key) is the workaround, but it adds significant complexity.

**Don't use it when you lack operational maturity.** Event stores need monitoring, projection lag tracking, schema migration tooling. If you're a small team shipping fast, this overhead might slow you down more than it helps.

**Don't use it as a debugging crutch.** "We can replay events to find bugs" is true, but if you need to do this often, you have a testing problem, not a persistence problem.

The canonical use cases are: financial systems (where audit trails are mandatory), collaborative editing (where conflict resolution needs event history), systems with complex business rules that evolve over time, and applications where multiple teams need different read models of the same underlying data.

## The Bottom Line

Event sourcing trades immediate simplicity for long-term flexibility. You're building infrastructure that pays dividends when requirements change—and they always change. But that infrastructure has a carrying cost.

Elixir makes this trade-off more palatable than most languages. Pattern matching turns event handlers into clean, declarative code. GenServers provide natural homes for projections. The immutability of Elixir's data structures aligns perfectly with the immutability of event logs. The BEAM's concurrency model handles thousands of projection processes without breaking a sweat.

Start with the simplest thing that works. If that's a CRUD app with PostgreSQL, ship it. When you hit the wall—when auditing becomes painful, when debugging state corruption consumes your week, when regulatory requirements demand complete history—event sourcing will be waiting. And Elixir will make the implementation cleaner than you'd expect.

---

**Claims to verify with current data:**

- Commanded library features and API (verify against current documentation)
- PostgreSQL NOTIFY syntax and integration patterns with Ecto
- `:erlang.term_to_binary/1` format compatibility across OTP versions for snapshot storage
