%{
title: "Understanding BEAM Memory Management",
category: "Programming",
tags: ["elixir", "beam", "performance", "memory"],
description: "Process heaps, garbage collection, and memory profiling in Elixir",
published: false
}
---

# Understanding BEAM Memory Management

Most developers coming to Elixir carry assumptions about memory that don't apply. They've internalized the shared-heap model of the JVM or the manual memory dance of C++. Then they hit their first "memory leak" in a BEAM application and find themselves in unfamiliar territory.

The BEAM virtual machine doesn't work like other runtimes. That's not marketing — it's architecture. And understanding this architecture is the difference between debugging memory issues in minutes versus days.

## The Per-Process Heap: Isolation as a Feature

Here's the fundamental insight: every Erlang process has its own private heap. Not threads sharing a heap. Not green threads with a global allocator. Each process — and a typical Elixir application runs thousands of them — maintains its own memory space.

This design choice has consequences that cascade through everything else.

When Process A sends a message to Process B, that data is copied. Fully. The sender's heap and the receiver's heap never share references. This sounds expensive, and sometimes it is. But it buys you something profound: a process can garbage collect independently, without stopping the world.

```elixir
# Each process has its own heap
spawn(fn ->
  # This list lives on this process's heap
  data = Enum.to_list(1..10_000)

  # When this process dies, its heap is reclaimed instantly
  # No GC pause. No mark-and-sweep. Just gone.
end)
```

The JVM's garbage collector is a marvel of engineering. It has to be — it's managing a single heap accessed by dozens of threads with complex synchronization requirements. The BEAM sidesteps this complexity entirely. When a process dies, its memory is reclaimed in constant time. No scanning. No compaction. The allocator just takes it back.

This is why Elixir applications can run for years without the dreaded GC pauses that plague other managed runtimes. The worst-case GC pause is bounded by the largest process heap, not the total application memory.

## Generational Garbage Collection: The Young Die Fast

Within each process, the BEAM uses generational garbage collection. The hypothesis is familiar: most allocations are short-lived. The implementation is not.

BEAM divides each process heap into two generations. The young generation holds recently allocated data. When it fills up, a minor GC runs — scanning only the young generation, promoting survivors to the old generation.

Here's where it gets interesting. The VM tracks a counter called `fullsweep_after`. After this many minor collections, the next GC becomes a major collection, scanning both generations. The default is 65535 — essentially, major collections almost never happen through normal operation.

```elixir
# Check a process's GC settings
Process.info(self(), :garbage_collection)
# => [garbage_collection: [max_heap_size: %{error_logger: true, kill: true, size: 0},
#     min_bin_vheap_size: 46422, min_heap_size: 233, fullsweep_after: 65535, ...]]

# Force a specific process to do a full sweep
:erlang.garbage_collect(pid)

# Tune fullsweep_after for a specific process
spawn_opt(fn ->
  # Long-running process that accumulates old data
  some_stateful_work()
end, fullsweep_after: 10)
```

The `fullsweep_after` tuning matters for long-running processes that accumulate references in the old generation. A GenServer holding onto a large cache, for instance. If you never trigger a full sweep, old garbage can linger indefinitely.

But here's the trap: tuning GC parameters is almost never the right first move. It's the knob you reach for after you've profiled, understood, and exhausted simpler options. I've seen teams spend weeks tuning GC when the real problem was a single `:ets` table growing without bounds.

## Binary Handling: Where the Abstraction Leaks

Binaries in Erlang are where the per-process isolation model gets complicated. The BEAM uses two different storage strategies depending on size.

**Heap binaries** (64 bytes or smaller) live directly on the process heap. They're copied on message send, collected with normal GC, and behave exactly like any other term.

**Reference-counted binaries** (larger than 64 bytes) live in a shared heap with reference counting. Processes hold references to them, and the binary is freed when the last reference drops.

```elixir
# This is a heap binary - copied on send
small = "hello world"

# This is a refc binary - reference counted
large = String.duplicate("x", 100)

# You can check which you're dealing with
:erts_debug.size(small)  # Includes the binary data
:erts_debug.size(large)  # Just the reference, not the data
```

The 64-byte threshold exists because copying small binaries is cheaper than maintaining reference counts. But refc binaries create a category of memory issues that don't exist elsewhere in the BEAM.

Consider this pattern:

```elixir
def process_chunk(<<chunk::binary-size(100), rest::binary>>) do
  # 'chunk' is a sub-binary pointing into the original
  store_somewhere(chunk)
  process_chunk(rest)
end
```

That `chunk` isn't a copy. It's a reference into the original binary. If you store those chunk references and discard the "rest", the entire original binary stays in memory. I've seen 50MB binaries kept alive by a 100-byte reference to their middle.

The fix is explicit copying:

```elixir
def process_chunk(<<chunk::binary-size(100), rest::binary>>) do
  # Force a copy, releasing the reference to the original
  chunk_copy = :binary.copy(chunk)
  store_somewhere(chunk_copy)
  process_chunk(rest)
end
```

## Common Memory Issues and Their Signatures

After debugging memory issues in production Elixir systems, patterns emerge. Here are the ones I see repeatedly.

### The Binary Leak

Symptoms: Memory grows over time. `:erlang.memory(:binary)` shows large allocation. No single process seems responsible.

The cause is usually sub-binary references keeping parent binaries alive. HTTP bodies, file reads, anything that pattern-matches on large binaries.

```elixir
# Diagnosis
:recon.bin_leak(10)
# Returns: [{pid, binary_memory, [{binary_size, binary_count}]}]

# Often reveals processes holding unexpected binary references
```

### The Mailbox Bomb

Symptoms: A single process's memory spikes. The process is slow or unresponsive.

A producer is sending messages faster than a consumer can process them. The mailbox grows without bound.

```elixir
# Check mailbox size
Process.info(pid, :message_queue_len)
# => {:message_queue_len, 847293}  # This is bad

# Prevention: Use GenStage or Broadway for backpressure
# Or implement explicit acknowledgment patterns
```

### The ETS Accumulator

Symptoms: Memory grows. `:erlang.memory(:ets)` is the culprit. But your code doesn't use ETS directly.

Many libraries create ETS tables. Telemetry, connection pools, caches. If entries are inserted but never deleted, memory grows forever.

```elixir
# List all ETS tables and their sizes
:ets.all()
|> Enum.map(fn table ->
  info = :ets.info(table)
  {table, info[:name], info[:size], info[:memory] * :erlang.system_info(:wordsize)}
end)
|> Enum.sort_by(fn {_, _, _, mem} -> mem end, :desc)
|> Enum.take(10)
```

### Large Message Copying

Symptoms: High CPU during message passing. Memory spikes correlate with inter-process communication.

Remember: messages are copied. Sending a 100MB data structure between processes copies 100MB. Twice, if you're using `GenServer.call` and waiting for a reply.

```elixir
# Instead of sending large data
GenServer.cast(worker, {:process, huge_data})

# Consider sending a reference to shared storage
:ets.insert(:shared_data, {ref, huge_data})
GenServer.cast(worker, {:process_ref, ref})
```

## Profiling Tools: Seeing What's Actually Happening

The BEAM ships with excellent introspection capabilities. External tools like `:recon` extend them further.

### :erlang.memory/0

The first stop for any memory investigation:

```elixir
:erlang.memory()
# => [
#   total: 48821592,
#   processes: 12547832,
#   processes_used: 12546016,
#   system: 36273760,
#   atom: 446457,
#   atom_used: 432718,
#   binary: 1834120,
#   code: 11177553,
#   ets: 906224
# ]
```

The `binary` number tells you about refc binaries. The `processes` number tells you about process heaps. The `ets` number tells you about table storage. If one of these is growing unexpectedly, you've narrowed the search.

### :recon for Production Debugging

The `:recon` library provides battle-tested production debugging tools:

```elixir
# Add to mix.exs
{:recon, "~> 2.5"}

# Find processes using the most memory
:recon.proc_count(:memory, 10)

# Find processes with the largest mailboxes
:recon.proc_count(:message_queue_len, 10)

# Track binary memory to specific processes
:recon.bin_leak(10)

# Get detailed info about a specific process
:recon.info(pid)
```

### Observer for Development

In development, `:observer` provides a graphical view:

```elixir
:observer.start()
```

The Applications tab shows supervision trees. The Processes tab lets you sort by memory, message queue, or reductions. The System tab shows memory allocation over time.

Don't use Observer in production. It adds overhead and requires a graphical connection. Use `:recon` instead.

### Process-Level Inspection

For drilling into specific processes:

```elixir
# Everything about a process
Process.info(pid)

# Specific attributes
Process.info(pid, [:memory, :heap_size, :total_heap_size, :garbage_collection])

# Current stack trace (useful for stuck processes)
Process.info(pid, :current_stacktrace)
```

## Practical Memory Optimization

With diagnostics covered, here are concrete optimization patterns.

### Hibernate Long-Running Processes

Processes that spend most of their time waiting can hibernate:

```elixir
defmodule MyWorker do
  use GenServer

  def handle_info(:timeout, state) do
    # After processing, hibernate until next message
    {:noreply, state, :hibernate}
  end
end
```

Hibernation triggers a full GC and shrinks the heap to minimum size. The process wakes on the next message. Use this for processes that handle infrequent events.

### Stream Large Data Processing

Don't load entire files into memory:

```elixir
# Bad: loads entire file
File.read!("large.csv")
|> String.split("\n")
|> Enum.map(&process_line/1)

# Good: streams line by line
File.stream!("large.csv")
|> Stream.map(&process_line/1)
|> Stream.run()
```

### Use ETS for Shared Read-Heavy Data

When multiple processes need access to the same data:

```elixir
# Instead of passing large data to each process
Enum.each(workers, fn pid ->
  send(pid, {:config, large_config_map})
end)

# Use ETS with read_concurrency
:ets.new(:config, [:named_table, :public, read_concurrency: true])
:ets.insert(:config, {:settings, large_config_map})
# Processes read directly: :ets.lookup(:config, :settings)
```

### Copy Sub-Binaries Explicitly

When storing parts of larger binaries:

```elixir
def extract_header(<<header::binary-size(20), _rest::binary>>) do
  # Explicit copy breaks the reference
  :binary.copy(header)
end
```

## When to Worry: The Premature Optimization Trap

Memory optimization in Elixir follows a power law. A tiny fraction of code causes the vast majority of memory issues. Optimizing everything is wasted effort.

Worry about memory when:

- Production monitoring shows memory growing over time without plateau
- `:erlang.memory()` shows a specific category growing unexpectedly
- Processes are being killed by `max_heap_size` limits
- Response latency spikes correlate with GC activity

Don't worry about memory when:

- You're writing a new feature and haven't measured anything
- Memory usage is stable under production load
- You're optimizing a code path that runs once at startup
- The "optimization" makes code significantly harder to understand

The BEAM's memory model is forgiving. Per-process heaps mean memory issues are contained. Dead processes release their memory instantly. The GC is incremental and low-latency.

Most Elixir applications never need memory tuning. They need correct code, appropriate data structures, and respect for the message-passing paradigm. When you do need to optimize, measure first. The tools exist. Use them.

The goal isn't minimal memory usage. It's predictable memory behavior that doesn't degrade over time. A system that uses 2GB stably is better than one that uses 500MB and grows indefinitely.

Understand the model. Profile when problems arise. Fix the actual bottleneck. Everything else is noise.

---

*Claims to verify: The 64-byte threshold for heap vs refc binaries is accurate for recent OTP versions but may change. The default `fullsweep_after` value of 65535 should be verified against your OTP version. Specific `:recon` function signatures should be checked against the current library version.*
