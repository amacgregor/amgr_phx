%{
title: "Debugging Production Elixir with Observer and Recon",
category: "Programming",
tags: ["elixir", "debugging", "production", "observability"],
description: "Remote shell access, process inspection, and tracing in production safely",
published: false
}
---

It is 3 AM. Your phone starts buzzing. The production dashboard shows request latency climbing from 50ms to 12 seconds. Memory usage is spiking. Users are churning. You have two options: restart the node and hope, or connect to the running system and actually understand what is happening.

If you choose the first option, stop reading. This article is for engineers who want to diagnose problems, not defer them.

The BEAM virtual machine gives us something rare in production systems: the ability to inspect, trace, and modify running processes without stopping them. This is not a parlor trick. It is a fundamental architectural decision that the Erlang ecosystem made decades ago, and it remains one of Elixir's most underutilized capabilities.

## The Remote Shell: Your Entry Point

Before you can debug anything, you need access to the running node. IEx provides this through the `--remsh` flag, which establishes a remote shell connection to a named Erlang node.

Your production node needs to be started with a name. In a typical release, this happens via your `rel/env.sh.eex` or through environment variables:

```bash
# Named node with full hostname
elixir --name myapp@prod-server-01.example.com -S mix phx.server

# Named node with short name (single host or local development)
elixir --sname myapp -S mix phx.server
```

To connect from another machine, you need three things: the node name, network access, and a matching Erlang cookie. The cookie is a shared secret that authorizes node-to-node communication.

```bash
# Connect to the remote node
iex --name debug@your-machine.example.com \
    --cookie YOUR_PRODUCTION_COOKIE \
    --remsh myapp@prod-server-01.example.com
```

Once connected, you are inside the production runtime. Every command you type executes in that node's process space. This is power. This is also danger.

A few rules for remote shell sessions:

1. Never paste untested code. Compile errors in a remote shell can behave unpredictably.
2. Avoid blocking the shell process on long-running operations.
3. Keep your session short. Idle connections consume resources.
4. Use read-only operations first. Mutate only when you understand the system state.

For production nodes behind firewalls, establish an SSH tunnel first:

```bash
ssh -L 4369:localhost:4369 -L 9001:localhost:9001 prod-server-01.example.com
```

Port 4369 is EPMD (Erlang Port Mapper Daemon), which maps node names to ports. Port 9001 is an example distribution port — your node's actual port may differ.

## Observer: The Visual Debugger

Observer is Erlang's built-in GUI for system inspection. Most developers know it from local development but never connect it to production nodes. That is a mistake.

To run Observer locally and connect to a remote node:

```elixir
# First, ensure your local node is started with distribution
iex --name observer@localhost --cookie YOUR_PRODUCTION_COOKIE

# Then connect to the remote node
Node.connect(:"myapp@prod-server-01.example.com")

# Start Observer
:observer.start()
```

Once Observer launches, navigate to `Nodes` in the menu bar and select your production node. You now have a live view of processes, memory allocation, and system statistics.

The `Applications` tab shows your supervision tree. The `Processes` tab lets you sort by message queue length, memory usage, or reductions. The `System` tab provides an overview of schedulers, memory, and I/O.

One caveat: Observer adds overhead. The GUI polls the remote node for data, which consumes CPU and network bandwidth. Do not leave it connected for extended periods on heavily loaded systems. Get your data and disconnect.

## Process Inspection: Finding the Culprit

When latency spikes or memory climbs, a process is usually responsible. Your job is to find it.

The `:recon` library is essential for production debugging. Add it to your dependencies:

```elixir
# mix.exs
{:recon, "~> 2.5"}
```

Now you have surgical tools for process inspection.

### Finding Heavy Processes

```elixir
# Top 10 processes by memory usage
:recon.proc_count(:memory, 10)

# Top 10 processes by message queue length
:recon.proc_count(:message_queue_len, 10)

# Top 10 processes by heap size
:recon.proc_count(:heap_size, 10)

# Top 10 processes by reductions (CPU work) over a 1-second window
:recon.proc_window(:reductions, 10, 1000)
```

The difference between `proc_count` and `proc_window` matters. `proc_count` gives you a snapshot — who has the most right now. `proc_window` gives you a delta — who did the most work during the measurement period. Use `proc_window` for CPU-bound issues; use `proc_count` for accumulation problems like message queues.

### Deep Process Inspection

Once you identify a suspicious process, dig deeper:

```elixir
pid = pid(0, 1234, 0)  # Construct a PID from the tuple notation

# Basic info
Process.info(pid, [:registered_name, :current_function, :message_queue_len])

# Full info dump
Process.info(pid)

# Erlang-level details
:erlang.process_info(pid, :current_stacktrace)
```

The `current_stacktrace` key is gold. It tells you exactly what that process is doing right now. If you see a process stuck in a blocking call to an external service, you have found your bottleneck.

For GenServers, check the state directly:

```elixir
:sys.get_state(pid)
```

If the state is enormous — say, a list with 500,000 items — you have found your memory problem.

## Memory Leak Hunting

Elixir processes have independent heaps, which simplifies garbage collection but complicates memory debugging. A leak might be in a single process hoarding data, or it might be binary references held across process boundaries.

### Binary Leaks

Binary data larger than 64 bytes lives in a shared heap and is reference-counted. If a process holds a reference to a sub-binary (a slice of a larger binary), the entire original binary stays in memory until all references are released.

This pattern causes leaks:

```elixir
def parse_header(<<header::binary-size(4), _rest::binary>>) do
  # header is a sub-binary referencing the entire original binary
  {:ok, header}
end
```

The `:recon` library can find processes holding onto binary references:

```elixir
# Find processes with the most binary memory
:recon.bin_leak(10)
```

This returns processes sorted by the difference between their binary virtual heap size and their actual binary memory usage — a heuristic for leak potential.

### Allocator Analysis

For system-wide memory issues, `:recon_alloc` provides visibility into the BEAM's memory allocators:

```elixir
# Memory usage by allocator type
:recon_alloc.memory(:usage)

# Fragmentation statistics
:recon_alloc.memory(:allocated)

# Cache hit rates for allocators
:recon_alloc.cache_hit_rates()
```

High fragmentation (allocated >> used) indicates the allocators are holding onto memory they cannot efficiently reuse. This often happens with highly variable workload patterns. Sometimes the answer is restarting the node; sometimes it is tuning allocator flags.

## Tracing in Production

Tracing lets you observe function calls, arguments, and return values in real time. It is also the fastest way to crash a production node if you do it wrong.

Never use `:dbg` or `:erlang.trace` directly in production. They have no rate limiting. A function called 50,000 times per second will generate 50,000 trace messages per second, overwhelming your shell and potentially the node.

Use `:recon_trace` instead. It has built-in rate limiting:

```elixir
# Trace calls to MyApp.Worker.process/2, max 100 traces total
:recon_trace.calls({MyApp.Worker, :process, 2}, 100)

# Trace with return values
:recon_trace.calls({MyApp.Worker, :process, 2}, 100, [{:return_trace}])

# Trace all functions in a module, 50 traces per second, max 1000 total
:recon_trace.calls({MyApp.Worker, :_, :_}, {1000, 50}, [])
```

The rate limiting format `{max_traces, traces_per_second}` is your safety valve. Start conservative. You can always increase the limit; you cannot un-crash a node.

To stop all tracing:

```elixir
:recon_trace.clear()
```

### Match Specs for Surgical Tracing

Sometimes you only want to trace calls with specific arguments:

```elixir
# Trace only when the first argument is :error
:recon_trace.calls(
  {MyApp.Handler, :handle_event, [{[:error, :_], [], [{:return_trace}]}]},
  100
)
```

Match specs use Erlang's pattern matching syntax. The format is `[{pattern, guards, actions}]`. Learn them; they are the difference between useful traces and noise.

### Tracing by Process

You can also restrict tracing to specific processes:

```elixir
# Trace calls only from a specific process
pid = Process.whereis(MyApp.ProblematicWorker)
:recon_trace.calls({MyApp.Database, :query, :_}, 100, [{:scope, [pid]}])
```

This dramatically reduces noise when you already know which process is misbehaving but want to understand what it is calling.

## GenServer Debugging with :sys

The `:sys` module provides introspection hooks for any process built on OTP behaviors. Every GenServer, GenStage, and GenStateMachine supports these functions. These tools are built into OTP itself — no dependencies required.

```elixir
pid = Process.whereis(MyApp.Worker)

# Get the current state
:sys.get_state(pid)

# Get formatted status (includes state, message queue, etc.)
:sys.get_status(pid)

# Enable trace messages for this process
:sys.trace(pid, true)

# Disable tracing
:sys.trace(pid, false)
```

The `trace/2` function outputs debug messages to the shell for every event the process handles. Unlike `:recon_trace`, this is process-specific and relatively low overhead.

For stuck processes, `:sys.get_status/1` reveals whether the process is waiting for a message, handling a call, or blocked in a function.

### Suspending and Resuming Processes

When you need to freeze a process to inspect it without it processing more messages:

```elixir
# Suspend the process — it stops handling messages
:sys.suspend(pid)

# Inspect state while frozen
state = :sys.get_state(pid)

# Resume normal operation
:sys.resume(pid)
```

This is invaluable when debugging race conditions. Suspend the suspect process, examine its state, then resume. The messages queue up during suspension and process normally after resume.

### Replacing State in Running Processes

In emergencies, you can modify a GenServer's state without restarting it:

```elixir
:sys.replace_state(pid, fn state ->
  # Return the new state
  %{state | stuck_flag: false}
end)
```

Use this sparingly. It violates the normal message-passing model and can introduce inconsistencies if you are not careful. But when you need to unstick a process at 3 AM without a deployment, it is there.

## War Stories

Theory is useful. Experience is better. Here are three debugging sessions from production systems.

### The Binary That Would Not Die

A Phoenix application leaked 2GB of memory over 48 hours. The standard metrics showed no single process with outsized memory. `:recon.bin_leak(20)` revealed a GenServer that processed file uploads and stored parsed headers in its state.

The culprit: headers were extracted as sub-binaries from the original upload. The GenServer held these tiny headers, but the reference-counting system kept the entire multi-megabyte upload binary alive.

The fix: force a copy of the header data.

```elixir
def parse_header(<<header::binary-size(4), _rest::binary>>) do
  {:ok, :binary.copy(header)}  # Breaks the reference to the parent binary
end
```

Thirty seconds of inspection. Three lines of code. Problem solved.

### The Queue That Ate the Node

A messaging application experienced cascading latency. `:recon.proc_count(:message_queue_len, 5)` showed a single process with 340,000 pending messages.

The process was a GenServer that wrote events to an external database. The database had become slow due to an unrelated index problem. The GenServer's mailbox filled faster than it could drain.

The immediate fix: kill the process. Supervision restarted it with an empty queue, and backpressure from the caller side kicked in.

The permanent fix: implement a bounded mailbox pattern using GenStage or manual queue limiting with explicit backpressure signals.

### The Runaway Recursion

CPU usage spiked to 100% on two of eight schedulers. `:recon.proc_window(:reductions, 5, 1000)` identified two processes burning through reductions at 10x the rate of anything else.

`:erlang.process_info(pid, :current_stacktrace)` showed both processes deep in a recursive function that had no termination condition for a specific edge case in input data.

The fix required a code deployment, but the diagnosis took under two minutes. Without BEAM introspection, we would have been guessing.

### The Silent Deadlock

Two GenServers called each other synchronously. Under normal load, the calls completed fast enough that the 5-second timeout never triggered. Under heavy load, both processes occasionally called each other simultaneously, each waiting for the other to respond. Classic deadlock.

The symptom was intermittent timeouts with no obvious pattern. `:sys.get_status/1` on both processes showed them in a `waiting` state. The stack traces revealed they were both blocked in `GenServer.call/3`, waiting for each other.

The fix: convert one of the calls to `cast` (fire-and-forget) and handle the response asynchronously. The diagnosis revealed an architectural flaw that had been latent for months.

## The Discipline of Production Debugging

These tools are powerful. They are not magic. Effective production debugging requires discipline:

1. **Hypothesize before you instrument.** Random exploration wastes time. Form a theory about what is wrong, then gather evidence to confirm or refute it.

2. **Start with the least invasive tools.** `:recon.proc_count` and `:recon.proc_window` add minimal overhead. Tracing adds more. `:observer` adds more still. Escalate only when necessary.

3. **Document what you find.** The patterns that cause problems in your system will recur. Build runbooks.

4. **Practice in staging.** The first time you connect a remote shell should not be during an incident. Build muscle memory when the stakes are low.

The BEAM gives you the ability to understand running systems. Most platforms require you to fly blind, inferring behavior from logs and metrics after the fact. Elixir lets you open the hood while the engine is running.

Use that power. But use it wisely.

---

*Key claims to verify with current data:*
- *Recon library version (~> 2.5 as of writing; check hex.pm for latest)*
- *Default sub-binary threshold of 64 bytes may vary by OTP version*
- *EPMD default port 4369 is standard but can be configured differently*
