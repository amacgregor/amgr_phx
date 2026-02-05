%{
title: "Flow Based Programming With Elixir",
category: "Programming",
tags: ["elixir","functional programming","programming","fbp"],
description: "Explaining flow based programming using elixir and its ecosystem",
published: true
}
---

<!--Explaining Flow-based programming using Elixir and its ecosystem-->

In 1971, J. Paul Morrison was working at IBM and stumbled onto an idea that was decades ahead of its time. He called it **Flow-Based Programming** — a paradigm where applications are networks of independent processes exchanging data through message passing. The industry largely ignored it. Object-oriented programming was on the rise, and the world wanted classes, not data factories.

Fifty years later, Elixir ships with a runtime that implements Morrison's vision as a first-class execution model. The BEAM virtual machine doesn't just support FBP-style architectures. It was *built* for them.

I wrote a [brief introduction to FBP](https://allanmacgregor.com/posts/20191020-wtf-is-flow-based-programming) a while back and promised to go deeper. This is that article. We're going to map FBP's core concepts directly onto Elixir primitives, build concrete data pipelines with GenStage and Flow, and examine why this paradigm — born in the era of mainframes — turns out to be the right mental model for modern concurrent systems.

## A Quick Refresher on FBP

Back in 2017, I had the chance to meet J. Paul Morrison himself. The way he explained FBP stuck with me: think of your application as a **data processing factory**. Data moves along conveyor belts. Each station on the belt is an independent process — a black box with defined inputs and outputs. The stations don't know about each other. They just do their job and pass the data along.

The formal model has a few key concepts:

- **Information Packets (IPs)**: Discrete chunks of data that flow through the network. Not streams. Not shared memory. Distinct, owned data structures.
- **Components**: Black box processes with defined input and output ports. A component's internal logic is invisible to the rest of the network.
- **Connections**: Bounded buffers between components, defined externally. The component doesn't decide who it talks to — the network definition does.
- **External Coordination**: The network topology is defined outside the components. You can rewire the factory without rewriting the machines.

This is not just "piping data between functions." The bounded buffers create natural **back-pressure**. The external wiring creates **composability**. The black box isolation creates **fault boundaries**.

Sound familiar?

## The BEAM Was Built for This

Here's where it gets interesting. Let's map Morrison's concepts onto Elixir's runtime:

| **FBP Concept** | **Elixir Equivalent** |
|---|---|
| Component (black box process) | BEAM process |
| Information Packet | Message |
| Connection (bounded buffer) | Process mailbox / GenStage demand |
| Network definition | Supervision tree + pipeline configuration |
| Component isolation | Process isolation (separate heap, no shared state) |
| Failure handling | OTP supervisors |

This isn't a forced analogy. The alignment is structural.

A BEAM process is lightweight — roughly 2KB of initial memory. You can spawn millions of them on a single machine. Each process has its own heap, its own garbage collector, and communicates exclusively through message passing. When a process crashes, it takes nothing else down with it.

That's Morrison's black box model, implemented at the virtual machine level. Other languages and runtimes can simulate this with libraries. Elixir's runtime *is* this.

The supervision tree deserves special attention here. In FBP, the network topology is defined externally — you wire components together from outside. OTP supervisors serve exactly this function. They define which processes exist, how they relate to each other, and what happens when one fails. The supervisor is the factory floor manager.

## GenStage: FBP With Back-Pressure

Elixir's [GenStage](https://github.com/elixir-lang/gen_stage) library is the most direct implementation of FBP principles in the ecosystem. It defines a pipeline of stages where each stage is a producer, a consumer, or both.

The critical insight is **demand-driven data flow**. Consumers tell producers how much data they can handle. Producers only emit that much. This is Morrison's bounded buffer concept — implemented as a protocol rather than a fixed-size queue.

Let's build something concrete. Imagine we need to process a stream of events: read them from a source, transform them, and write them to a sink.

### The Producer

```elixir
defmodule EventProducer do
  use GenStage

  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:producer, %{events: []}}
  end

  def handle_demand(demand, state) when demand > 0 do
    events = fetch_events(demand)
    {:noreply, events, state}
  end

  defp fetch_events(count) do
    # In production, this reads from a database, API, or message queue
    Enum.map(1..count, fn i ->
      %{id: i, type: :page_view, timestamp: DateTime.utc_now(), payload: %{url: "/page/#{i}"}}
    end)
  end
end
```

The producer only generates events when downstream stages ask for them. No buffering. No overflow. Demand flows upstream, data flows downstream.

### The Transformer

```elixir
defmodule EventTransformer do
  use GenStage

  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:producer_consumer, %{}, subscribe_to: [{EventProducer, max_demand: 100}]}
  end

  def handle_events(events, _from, state) do
    transformed =
      events
      |> Enum.filter(&valid_event?/1)
      |> Enum.map(&enrich_event/1)

    {:noreply, transformed, state}
  end

  defp valid_event?(%{type: type}) when type in [:page_view, :click, :purchase], do: true
  defp valid_event?(_), do: false

  defp enrich_event(event) do
    Map.merge(event, %{
      processed_at: DateTime.utc_now(),
      day_of_week: Date.day_of_week(DateTime.to_date(event.timestamp))
    })
  end
end
```

This stage is a **producer_consumer** — it consumes events from the producer, transforms them, and emits them downstream. Notice the `max_demand: 100`. That's the bounded buffer. The transformer will never request more than 100 events at a time from the producer.

### The Consumer

```elixir
defmodule EventConsumer do
  use GenStage

  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, %{}, subscribe_to: [{EventTransformer, max_demand: 50}]}
  end

  def handle_events(events, _from, state) do
    Enum.each(events, fn event ->
      persist_event(event)
    end)

    {:noreply, [], state}
  end

  defp persist_event(event) do
    # Write to database, send to external service, etc.
    IO.inspect(event, label: "Persisted")
  end
end
```

### Wiring the Network

Here's where FBP's external coordination principle shows up. We define the network topology in our application supervisor — outside the components themselves:

```elixir
defmodule EventPipeline.Application do
  use Application

  def start(_type, _args) do
    children = [
      EventProducer,
      EventTransformer,
      EventConsumer
    ]

    opts = [strategy: :rest_for_one, name: EventPipeline.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

The `rest_for_one` strategy is deliberate. If the producer crashes, everything downstream restarts. If the consumer crashes, only the consumer restarts. The supervision strategy encodes the data flow dependency graph. Morrison would recognize this immediately.

## Flow: Parallel FBP Without the Boilerplate

GenStage gives you fine-grained control. But for many data processing tasks, you want the FBP model without manually wiring every stage. That's what [Flow](https://github.com/dashbit/flow) provides.

Flow builds on GenStage to give you parallel, partitioned data processing with a familiar API. Think of it as MapReduce that runs inside your application, backed by FBP semantics.

Here's a real-world example: processing a large log file to compute request statistics.

### The Imperative Approach

First, let's look at how you'd typically write this without FBP:

```elixir
defmodule LogAnalyzer.Imperative do
  def analyze(file_path) do
    file_path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_log_line/1)
    |> Enum.filter(&(&1.status >= 400))
    |> Enum.group_by(& &1.path)
    |> Enum.map(fn {path, entries} ->
      {path, %{count: length(entries), avg_response: avg_response_time(entries)}}
    end)
    |> Enum.sort_by(fn {_path, stats} -> stats.count end, :desc)
  end

  defp parse_log_line(line) do
    # Parse log format into structured data
    parts = String.split(line, " ")
    %{path: Enum.at(parts, 1), status: String.to_integer(Enum.at(parts, 2)),
      response_time: String.to_float(Enum.at(parts, 3))}
  end

  defp avg_response_time(entries) do
    entries |> Enum.map(& &1.response_time) |> Enum.sum() |> Kernel./(length(entries))
  end
end
```

This works. It's clear. But it has three problems that matter at scale:

1. **It reads the entire file into memory.** A 10GB log file will blow up your process.
2. **It's single-threaded.** Every `Enum` call processes elements sequentially.
3. **There's no back-pressure.** If parsing is fast but grouping is slow, there's no mechanism to balance the load.

### The Flow Approach

```elixir
defmodule LogAnalyzer.Flow do
  def analyze(file_path) do
    file_path
    |> File.stream!(read_ahead: 100_000)
    |> Flow.from_enumerable()
    |> Flow.map(&parse_log_line/1)
    |> Flow.filter(&(&1.status >= 400))
    |> Flow.partition(key: {:key, :path})
    |> Flow.reduce(fn -> %{} end, fn entry, acc ->
      Map.update(acc, entry.path, [entry], &[entry | &1])
    end)
    |> Flow.on_trigger(fn groups ->
      stats =
        Enum.map(groups, fn {path, entries} ->
          {path, %{count: length(entries), avg_response: avg_response_time(entries)}}
        end)

      {stats, %{}}
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.sort_by(fn {_path, stats} -> stats.count end, :desc)
  end

  defp parse_log_line(line) do
    parts = String.split(line, " ")
    %{path: Enum.at(parts, 1), status: String.to_integer(Enum.at(parts, 2)),
      response_time: String.to_float(Enum.at(parts, 3))}
  end

  defp avg_response_time(entries) do
    entries |> Enum.map(& &1.response_time) |> Enum.sum() |> Kernel./(length(entries))
  end
end
```

The API looks similar. The execution model is fundamentally different.

`File.stream!` reads lazily — no memory explosion. `Flow.from_enumerable` spawns GenStage producers behind the scenes. `Flow.partition(key: {:key, :path})` redistributes data across multiple processes so that all entries for the same path land in the same partition. The reduce and trigger happen in parallel across partitions.

Under the hood, Flow is building exactly the kind of FBP network Morrison described: a set of black box processes, connected by bounded buffers, with data flowing through the network driven by consumer demand. You just don't have to wire it manually.

## When FBP Breaks Down

I'd be dishonest if I didn't address the obvious objection: this is overengineering for simple tasks.

It is. If you're processing a hundred records from a database query, `Enum.map` is the right tool. GenStage and Flow add process management overhead that doesn't pay for itself at small scale. The process spawning, message passing, and demand negotiation all have real costs — measured in microseconds, but they exist.

FBP earns its keep when:

- **Data volume exceeds single-process capacity.** Once you need parallelism, you need coordination. FBP gives you coordination with back-pressure for free.
- **The pipeline has different throughput characteristics at each stage.** A fast parser feeding a slow database writer is the classic case. Back-pressure prevents the parser from overwhelming the writer.
- **Stages need independent failure domains.** If your enrichment service goes down, you don't want to lose the data you've already parsed. Process isolation gives you that boundary.
- **The pipeline topology changes.** Adding a new transformation step, splitting output to multiple sinks, or A/B testing different processing paths — FBP's external wiring makes these changes surgical.

There's also the "other languages do this" argument. And yes, Akka Streams in Scala, Go channels, and Rust's tokio all provide pipeline abstractions. The difference is foundational. Those languages add concurrency primitives on top of a runtime that wasn't designed for them. Elixir's BEAM runtime *is* a concurrent process engine. The overhead of spawning a GenStage producer in Elixir is measured in microseconds. The conceptual overhead is zero — it's just another process.

## Real-World Applications

FBP patterns in Elixir aren't theoretical. They're running in production across several domains:

**ETL Pipelines**: Extract-Transform-Load workflows are the textbook FBP use case. A GenStage producer reads from a source database, producer_consumers handle transformation and validation, and consumers write to the target. Broadway — built on GenStage — adds acknowledgement and batch processing for production ETL systems.

**Event Processing**: Systems that ingest events from multiple sources, enrich them, and route them to different destinations. Think clickstream analytics, audit logging, or notification dispatching. Flow's partitioning model handles the fan-out naturally.

**Data Ingestion**: Processing CSV uploads, API webhooks, or message queue consumers where data arrives faster than you can process it. GenStage's demand model prevents the kind of unbounded queue growth that crashes systems at 3 AM.

**Real-Time Dashboards**: Phoenix LiveView combined with GenStage creates a full pipeline from data source to user's browser. The GenStage pipeline processes and aggregates data; LiveView pushes updates to connected clients. The entire path is FBP — data flows from source to screen through a network of independent processes.

For production workloads, I'd recommend looking at [Broadway](https://github.com/dashbit/broadway) — a library from the Dashbit team that builds on GenStage to add features like automatic acknowledgement, batching, graceful shutdown, and built-in integrations with Amazon SQS, Google Cloud PubSub, RabbitMQ, and Kafka. Broadway is essentially production-grade FBP with batteries included.

## The Factory Floor

Morrison's insight from 1971 was that software should work like a factory: independent stations, conveyor belts between them, and a floor plan that defines the layout. He was right. The problem was that computers in 1971 couldn't efficiently run thousands of independent processes communicating through message passing.

The BEAM can. Elixir makes it ergonomic.

When you write a GenStage pipeline in Elixir, you're not using a library that simulates FBP concepts. You're using a runtime whose fundamental execution unit *is* the independent process, whose fundamental communication mechanism *is* message passing, and whose fundamental reliability model *is* isolated failure domains with external supervision.

FBP isn't a pattern you adopt in Elixir. It's the grain of the wood. You just have to stop fighting it and start cutting with it.
