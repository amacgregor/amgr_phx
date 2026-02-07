%{
title: "Building Resilient Systems with OTP Supervisors",
category: "Programming",
tags: ["elixir", "otp", "fault-tolerance", "architecture"],
description: "Deep dive into supervisor strategies and designing supervision trees for real-world fault tolerance",
published: false
}
---

# Building Resilient Systems with OTP Supervisors

Most developers approach error handling backwards. They write defensive code, wrap everything in try-catch blocks, and pray their validation logic catches every edge case. Then production happens.

OTP supervisors embody a different philosophy — one that acknowledges a fundamental truth about distributed systems: failure is not exceptional. It is inevitable. The question is not whether your processes will crash, but what happens when they do.

## The "Let It Crash" Philosophy, Properly Understood

"Let it crash" is the most misunderstood phrase in the Erlang ecosystem. It does not mean "be careless." It does not mean "ignore errors." It means: separate the concerns of normal operation from the concerns of error recovery.

Consider the alternative. In a traditional defensive programming model, every function must anticipate every possible failure mode. Your business logic becomes polluted with error handling code. A simple data transformation function grows tentacles of validation, fallback logic, and recovery attempts. The essential complexity of your domain drowns in the accidental complexity of defensive programming.

OTP inverts this. Your worker processes handle the happy path. They assume their inputs are valid, their dependencies are available, their state is consistent. When these assumptions break — and they will break — the process crashes. A supervisor, watching from above, notices the crash and makes a decision: restart the process, restart related processes, or escalate the failure up the tree.

This is not recklessness. This is architectural separation of concerns. The worker knows how to do work. The supervisor knows how to recover from failure. Neither pollutes the other's domain.

## Supervisor Strategies: Choosing Your Recovery Model

A supervisor's strategy determines how it responds when a child process dies. This choice encodes your assumptions about the relationships between your processes.

### one_for_one: Independent Workers

```elixir
defmodule MyApp.WorkerSupervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {MyApp.Worker, name: :worker_a},
      {MyApp.Worker, name: :worker_b},
      {MyApp.Worker, name: :worker_c}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

When worker_a crashes, only worker_a restarts. Workers B and C continue uninterrupted. Use this when your processes are genuinely independent — they share no state, have no ordering dependencies, and can operate in isolation.

This is the most common strategy and the correct default choice. If you are unsure which strategy to use, start here.

### one_for_all: Coordinated Restart

```elixir
defmodule MyApp.CoordinatedSupervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {MyApp.StateHolder, []},
      {MyApp.Processor, []},
      {MyApp.Publisher, []}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
```

When any child crashes, all children restart. This is appropriate when your processes form a cohesive unit with shared assumptions. If process A holds state that process B depends on, and A crashes, B's view of the world is now inconsistent. Restarting B alongside A ensures they begin from a known-good state together.

I use this strategy for tightly coupled subsystems — say, a cache process paired with its invalidation listener. If either dies, restarting both is cheaper than debugging the inconsistencies that arise from partial recovery.

### rest_for_one: Sequential Dependencies

```elixir
defmodule MyApp.PipelineSupervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {MyApp.DatabasePool, []},
      {MyApp.CacheWarmer, []},
      {MyApp.RequestHandler, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
```

When a child crashes, that child and all children started after it restart. The children started before it continue running. This models sequential dependencies: the database pool must exist before the cache warmer can run, and the cache must be warm before request handling makes sense.

This strategy is underutilized. Many systems have implicit ordering dependencies that developers handle through startup delays or retry loops. Making the dependency explicit in your supervision tree is cleaner.

### DynamicSupervisor: Runtime-Spawned Children

```elixir
defmodule MyApp.SessionSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_session(session_id) do
    spec = {MyApp.SessionWorker, session_id}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_session(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
```

DynamicSupervisor handles processes that come and go at runtime — user sessions, WebSocket connections, job workers pulled from a queue. You define no static children; instead, you spawn them on demand.

The strategy is always one_for_one conceptually, though you configure it explicitly. Each dynamic child is independent; when one crashes, only that child restarts.

## Restart Intensity: Tuning the Circuit Breaker

Every supervisor has two critical parameters: `max_restarts` and `max_seconds`. Together, they form a circuit breaker.

```elixir
Supervisor.init(children,
  strategy: :one_for_one,
  max_restarts: 3,
  max_seconds: 5
)
```

This configuration says: if more than 3 restarts occur within 5 seconds, stop trying. The supervisor itself crashes, escalating the failure to its parent.

The defaults (3 restarts in 5 seconds) are reasonable for many workloads. But they encode assumptions that may not match your domain.

**High-frequency, low-consequence work**: A worker processing messages from a queue might crash occasionally due to malformed data. If you process 10,000 messages per second and 0.01% are malformed, that is one crash per second. The default settings would trip the circuit breaker in three seconds, even though the system is functioning normally.

```elixir
# For high-throughput workers with occasional bad input
Supervisor.init(children,
  strategy: :one_for_one,
  max_restarts: 100,
  max_seconds: 1
)
```

**Expensive initialization**: If your worker takes 30 seconds to initialize (loading ML models, warming caches), rapid restarts waste enormous resources. Tighten the circuit breaker.

```elixir
# For workers with expensive initialization
Supervisor.init(children,
  strategy: :one_for_one,
  max_restarts: 2,
  max_seconds: 60
)
```

**External dependency failures**: If your worker crashes because a database is down, rapid restarts accomplish nothing except generating log noise. Let the circuit breaker trip quickly and rely on higher-level recovery mechanisms.

The right values depend on your failure modes. Instrument your supervisors. Measure your restart rates. Tune accordingly.

## Designing Supervision Trees: Failure Domain Isolation

A flat supervision tree — one supervisor with many children — is simple but brittle. When the supervisor's circuit breaker trips, everything underneath it dies. Every child shares a single failure budget.

Nested supervision trees isolate failure domains. Consider a web application with background jobs:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MyApp.Repo,
      {Phoenix.PubSub, name: MyApp.PubSub},
      MyApp.BackgroundJobs.Supervisor,
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule MyApp.BackgroundJobs.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {MyApp.BackgroundJobs.EmailWorkerSupervisor, []},
      {MyApp.BackgroundJobs.ReportGeneratorSupervisor, []},
      {MyApp.BackgroundJobs.DataSyncSupervisor, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

Now email worker crashes are isolated from report generation. The email subsystem can trip its circuit breaker without affecting reports. Each domain has its own failure budget.

The principle: group processes by failure correlation. Processes that fail together should be supervised together. Processes with independent failure modes should be supervised separately.

## Case Study: Designing a Data Pipeline Supervisor

Let me walk through a real design problem. We need a data pipeline that:
1. Maintains a pool of database connections
2. Consumes messages from a queue
3. Processes messages through multiple transformation stages
4. Writes results to an external API

Here is my supervision tree design:

```elixir
defmodule DataPipeline.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Infrastructure layer - must exist first
      DataPipeline.Infrastructure.Supervisor,
      # Processing layer - depends on infrastructure
      DataPipeline.Processing.Supervisor
    ]

    # rest_for_one: if infrastructure dies, restart processing too
    Supervisor.init(children, strategy: :rest_for_one)
  end
end

defmodule DataPipeline.Infrastructure.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Database pool - independent of queue connection
      {DataPipeline.DBPool, pool_size: 10},
      # API client pool - independent of database
      {DataPipeline.APIClient, pool_size: 5},
      # Queue connection - independent
      {DataPipeline.QueueConnection, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule DataPipeline.Processing.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Consumer pulls from queue, fans out to workers
      {DataPipeline.Consumer, []},
      # Dynamic pool of workers
      {DataPipeline.WorkerPool, []}
    ]

    # one_for_all: consumer and worker pool are tightly coupled
    Supervisor.init(children, strategy: :one_for_all)
  end
end

defmodule DataPipeline.WorkerPool do
  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 50,
      max_seconds: 10
    )
  end

  def start_worker(job) do
    spec = {DataPipeline.Worker, job}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end

defmodule DataPipeline.Worker do
  use GenServer, restart: :temporary

  def start_link(job) do
    GenServer.start_link(__MODULE__, job)
  end

  @impl true
  def init(job) do
    # Process immediately, then terminate
    send(self(), :process)
    {:ok, job}
  end

  @impl true
  def handle_info(:process, job) do
    result = process_job(job)
    publish_result(result)
    {:stop, :normal, job}
  end

  defp process_job(job) do
    # Transform data - crash on invalid input
    job
    |> validate!()
    |> transform()
    |> enrich_from_database()
  end

  defp publish_result(result) do
    DataPipeline.APIClient.publish(result)
  end
end
```

Notice the layered design. Infrastructure processes (database pool, API client, queue connection) are independent — one_for_one. They have their own failure budgets.

The processing layer depends on infrastructure. If infrastructure dies and restarts, we use rest_for_one to restart processing too. This ensures the consumer and workers reconnect to fresh infrastructure.

Within processing, the consumer and worker pool are tightly coupled — one_for_all. If the consumer dies, we want a clean slate for the worker pool too, and vice versa.

Individual workers use `restart: :temporary`. They process one job and exit. If they crash mid-job, the supervisor does not restart them — the job will be redelivered by the queue's own retry mechanism.

## Common Mistakes and Anti-Patterns

**Mistake: Supervising processes that should not crash.**

Not every process belongs in a supervision tree. Processes that represent transient operations — HTTP request handlers in Phoenix, Task processes for one-off work — often use `restart: :temporary` or are not supervised at all. Supervising them and restarting them makes no sense; the original context is gone.

**Mistake: Using one_for_all when processes are actually independent.**

I have seen teams use one_for_all "for safety" when their processes share no state. This is cargo culting. When an unrelated process crashes, you restart everything for no reason. Use one_for_one unless you have a specific coupling that requires coordinated restart.

**Mistake: Ignoring the circuit breaker.**

When a supervisor trips its circuit breaker, it is telling you something important: a child is failing faster than it can recover. This is a signal, not an error to suppress. Do not simply crank up max_restarts to make the problem go away. Investigate why the child is crashing repeatedly.

**Mistake: Putting everything under one supervisor.**

A single top-level supervisor with 15 children is a design smell. You have not thought about failure domains. A crash cascade in your email subsystem should not affect your payment processing. Split them.

**Mistake: Circular dependencies in rest_for_one.**

If process A depends on process B, and B depends on A, rest_for_one cannot save you. This is a design problem, not a supervision problem. Refactor to break the cycle.

**Mistake: Heavy initialization in worker init/1.**

If your worker's init/1 callback takes 30 seconds, and the worker crashes after 5 seconds of operation, you spend more time initializing than working. Move heavy initialization to a separate process that starts first and caches results, or use handle_continue/2 to defer initialization.

```elixir
@impl true
def init(args) do
  {:ok, %{status: :initializing}, {:continue, :initialize}}
end

@impl true
def handle_continue(:initialize, state) do
  # Heavy work here - process is already "started"
  model = load_ml_model()
  {:noreply, %{state | status: :ready, model: model}}
end
```

## Conclusion

Supervision trees are not error handling. They are system architecture. The decisions you make about supervisor strategies, restart intensities, and tree structure encode your understanding of how your system fails and how it recovers.

The best supervision tree designs I have seen share a common trait: they were designed by people who had watched their systems fail in production and learned from it. They knew which processes failed independently. They knew which failures cascaded. They knew which subsystems needed isolation.

You cannot design this from first principles alone. Deploy. Observe. Instrument your supervisors. Watch your restart rates. When something fails in production, ask: did the supervision tree do the right thing? If not, restructure it.

The "let it crash" philosophy is not about being cavalier with failure. It is about being systematic. It is about building systems where failure is not an emergency but a routine event, handled automatically, in the background, while your application continues serving users.

That is resilience.

---

**Claims to verify:**
- Default supervisor restart values (3 restarts in 5 seconds) should be verified against current OTP/Elixir documentation
- DynamicSupervisor internal strategy behavior may vary by Elixir version
- Specific syntax for supervisor child specs should be tested against your Elixir version (examples use Elixir 1.14+ conventions)
