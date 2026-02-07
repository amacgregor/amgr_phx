%{
title: "Setting Up Tidewave: BEAM Introspection for Agentic Workflows",
category: "Programming",
tags: ["elixir", "tidewave", "mcp", "ai", "debugging", "beam"],
description: "Expose BEAM process inspection, ETS exploration, and live tracing to your AI coding agent",
published: false
}
---

Your AI coding agent can read your source files. It can grep through your codebase. It can even run your test suite. But ask it what's actually happening inside your running application—which processes are consuming memory, what's sitting in your ETS tables, why that GenServer is blocking—and it draws a blank.

This is the gap Tidewave fills.

Dashbit released Tidewave in April 2025; it's an MCP server that plugs directly into your Phoenix application and exposes the BEAM's introspection capabilities to AI agents. No more copying and pasting `:observer` output into your chat window. No more manually running `:recon` commands and describing the results. The agent queries your runtime directly.

I've been running Tidewave in my development environment for the past three months. The shift in debugging workflow is substantial—not because the AI suddenly became smarter, but because it finally has eyes into what matters: the running system.

## What MCP Actually Is

Before we get into Tidewave specifically, we need to understand the infrastructure it builds on.

MCP stands for Model Context Protocol. Anthropic released the specification in late 2024; it defines a standardized way for AI assistants to access external tools and data sources. Think of it as a contract between an AI agent and the services it can call.

The protocol works through a simple request-response pattern. The AI agent describes what it wants to do—run a SQL query, fetch documentation, evaluate code—and the MCP server executes the action and returns the result. The agent never touches your system directly; it goes through this intermediary layer.

Why does this matter? Three reasons.

First, the AI doesn't need to understand your specific infrastructure. It just needs to know what tools are available and how to invoke them. The MCP server handles all the messy implementation details.

Second, you control exactly what the agent can access. Want to expose your database but not your file system? Configure the MCP server accordingly. Want to allow code evaluation but disable anything that writes to disk? That's a configuration option.

Third, the protocol is standardized. Claude Desktop, Cursor, Zed, and a growing list of editors all speak MCP. Write one server, connect to any compatible client.

Tidewave implements this protocol specifically for Elixir and Phoenix applications. When your Phoenix app starts in development mode, Tidewave spins up an MCP server inside your application process. Your AI agent connects to this server; suddenly it can query your running system the same way you would from IEx.

## Installing and Configuring Tidewave

Setup takes about five minutes. Maybe less if you're familiar with Phoenix endpoint configuration.

Start by adding the dependency to your `mix.exs`:

```elixir
defp deps do
  [
    # ... your other deps
    {:tidewave, "~> 0.5", only: :dev}
  ]
end
```

The `:only` option matters. Tidewave should never run in production; it exposes internal system state to external clients. Development only.

Run `mix deps.get` and then modify your endpoint. Open `lib/your_app_web/endpoint.ex` and add the Tidewave plug before your code reloading block:

```elixir
defmodule YourAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :your_app

  # Add this block BEFORE the code_reloading check
  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave
  end

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    # ...
  end

  # ... rest of your endpoint
end
```

The `Code.ensure_loaded?/1` check matters. The plug only activates when Tidewave is available—which, because of your `:only` specification, is only in dev. In production, this entire block becomes a no-op.

If you're using Phoenix LiveView 1.1 or later, add these options to your `config/dev.exs`:

```elixir
config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true
```

These settings enable enhanced debugging information that Tidewave can surface to your agent.

Now restart your Phoenix server:

```bash
mix phx.server
```

Tidewave starts automatically. You'll see a log message indicating the MCP server is running; it listens on the same port as your Phoenix app, handling MCP requests through a specific path.

The final step is connecting your AI agent. In Claude Desktop, open settings and add a new MCP server pointing to your local Phoenix instance. The exact configuration varies by client; consult your editor's MCP documentation for specifics.

For non-Phoenix Elixir projects, you can still use Tidewave—it just requires a bit more setup with Bandit as the HTTP server. Add both dependencies and create an alias that starts the server standalone.

## BEAM Introspection Via AI

Here's where Tidewave gets interesting.

The BEAM virtual machine is remarkably transparent. Every process, every ETS table, every supervision tree—it's all queryable at runtime. Erlang developers have used tools like `:observer`, `:recon`, and `:dbg` for decades to peer into running systems. The information was always there; getting it to your AI agent was the problem.

Tidewave exposes several MCP tools that map directly to BEAM introspection primitives:

**`project_eval`** - Execute arbitrary Elixir code within your application's runtime context. This is the escape hatch; anything you can do in IEx, you can ask your agent to do through this tool.

```elixir
# Agent can run this to get process info
Process.info(pid, [:memory, :message_queue_len, :current_function])
```

**`get_logs`** - Stream your application's log output. The agent sees exactly what you'd see in your terminal; stack traces, warnings, debug output.

**`execute_sql_query`** - Run queries against your application's database. Not a separate connection—the same Ecto repo your app uses, with the same configuration.

**`get_docs`** - Fetch documentation for any module or function, consulting the exact versions specified in your `mix.lock`. When the agent looks up `Phoenix.LiveView.push_event/3`, it gets the docs for whatever version you're actually running.

**`get_source_location`** - Find where a module or function is defined. Useful when the agent needs to understand implementation details.

**`get_models`** - List all modules in your application, with their source file locations.

The `project_eval` tool is particularly powerful. Through it, your agent can:

- List all processes and their memory consumption using `:erlang.processes()` and `Process.info/2`
- Query ETS tables directly with `:ets.tab2list/1`
- Trace function calls using `:dbg` or `:recon_trace`
- Inspect supervision trees with `Supervisor.which_children/1`
- Check message queue lengths across your system
- Evaluate the state of any GenServer

None of this is new capability. What's new is that the AI agent can do it without you translating back and forth. It asks questions; it gets answers; it asks follow-up questions based on those answers. The feedback loop tightens dramatically.

## Debugging a Real Problem

Theory is fine. Let me show you what this looks like in practice.

Last month I had a Phoenix application that was slowly consuming more memory over time. Classic leak symptoms; memory usage would climb over hours, eventually triggering the container's OOM killer. Nothing obvious in the code. No growing data structures I could identify.

With Tidewave connected, here's how the debugging session went.

I started by asking the agent to check overall process memory distribution. It ran something like:

```elixir
:erlang.processes()
|> Enum.map(fn pid ->
  case Process.info(pid, [:memory, :registered_name, :current_function]) do
    nil -> nil
    info -> {pid, info}
  end
end)
|> Enum.reject(&is_nil/1)
|> Enum.sort_by(fn {_pid, info} -> Keyword.get(info, :memory) end, :desc)
|> Enum.take(20)
```

The result showed a process consuming 340MB of memory—way more than anything else in the system. It wasn't a registered process; just a raw PID with no name.

I asked the agent to dig deeper. What was this process doing? What was in its state?

```elixir
Process.info(pid, [:current_function, :initial_call, :dictionary, :message_queue_len])
```

The process was a `Task.Supervisor` child. Its message queue had 47,000 pending messages.

That's your leak.

Something was spawning tasks faster than they could complete; the queue grew indefinitely.

The agent then helped trace where these tasks originated. Using the process dictionary and call stack information, we identified the source: a webhook handler that spawned a new task for every incoming event, without any backpressure mechanism. Under normal load, fine. Under a traffic spike, the system queued tasks faster than it could process them, and never recovered.

The fix was straightforward once we understood the problem—add a `PartitionSupervisor` with bounded concurrency. But finding the problem? That took thirty minutes with Tidewave versus what would have been hours of manual investigation.

The agent could explore the problem space directly. It didn't need me to run commands and paste output. It formulated hypotheses, tested them, and followed the evidence.

## The Feedback Loop

What makes Tidewave valuable isn't any single capability. It's the cycle.

Observe: The agent queries your running system. What processes exist? What's their memory footprint? What's in that ETS table?

Hypothesize: Based on observations, the agent forms a theory. This process has a growing message queue; maybe messages are arriving faster than they're processed.

Act: The agent takes action to test the hypothesis. It might trace function calls, query the database, or evaluate diagnostic code.

Observe again: New data comes back. The hypothesis is confirmed, refined, or discarded.

This loop is how experienced developers debug. You don't just stare at code; you poke the running system, watch how it responds, adjust your mental model, and poke again. Tidewave gives your AI agent the same capability.

The practical impact shows up in specific ways. Stack traces become more useful because the agent can look up the actual module source. Memory issues become tractable because the agent can enumerate processes and their sizes. Slow queries surface because the agent can check database statistics directly.

I've noticed my debugging prompts changing. Instead of describing a problem and asking for theories, I describe the symptom and ask the agent to investigate. "The dashboard is slow to load. Can you check what's happening when I refresh it?" The agent traces the request, times the database queries, identifies the N+1 problem, and proposes a fix. All in one interaction.

There's a compounding effect here. The more the agent learns about your specific application—its structure, its patterns, its quirks—the better it gets at navigating future problems. Tidewave provides the raw observational capability; your ongoing interactions build the contextual knowledge.

## Security Considerations

I've been emphatic about running Tidewave only in development. Let me be explicit about why.

Tidewave exposes your application's internals through an HTTP endpoint. In development, that endpoint is only accessible from localhost. The default configuration blocks remote connections.

But even with localhost restriction, consider what's exposed: arbitrary code evaluation, database queries, process inspection. If an attacker gained access to your development machine while Tidewave was running, they could extract secrets from environment variables, query your development database, or manipulate application state.

For local development, this is an acceptable tradeoff. You're already trusting your machine; the attack surface Tidewave adds is minimal compared to having your source code, database credentials, and terminal history all accessible.

In production? Absolutely not. Never. The `only: :dev` option in your dependency specification exists precisely for this reason.

A few precautions worth keeping in mind.

Don't run Tidewave on shared development servers. If multiple developers access the same machine, each can see—and potentially interfere with—each other's sessions.

Be thoughtful about what your development database contains. If you're working with production data copies (which has its own problems), Tidewave makes that data accessible to your AI agent, which means it potentially flows through whatever infrastructure your agent uses.

If you're using `allow_remote_access: true` for any reason—testing from a separate device, for example—understand that you've removed the localhost restriction. Anyone who can reach your development machine's port can access Tidewave.

The Tidewave team has been thoughtful about security defaults. Remote access is disabled out of the box; the plug only loads when the library is present; configuration options let you restrict capabilities. But defaults only help if you understand what they protect against.

## Where This Goes

Static analysis is table stakes now. Runtime intelligence is the differentiator. Tidewave represents a broader shift in how AI tools integrate with development workflows.

The BEAM has always been unusually inspectable. What Tidewave demonstrates is that this property—which felt like a nice-to-have for humans—becomes a significant advantage when AI agents enter the picture. Languages and runtimes that resist introspection give agents less to work with.

I expect we'll see similar tools for other platforms. The Ruby community already has Tidewave Rails support. Python's debugging and introspection tools could surface through MCP. The pattern is general even if the implementation is platform-specific.

For now, if you're building Phoenix applications, Tidewave is worth the five minutes of setup time. The mental model shift—from "I investigate, then describe to the AI" to "the AI investigates, I guide and validate"—changes how you approach problems.

Some things still require human judgment. The agent can find the memory leak; deciding whether to fix it with backpressure or partitioning or queue limits requires understanding your system's constraints. The agent proposes; you dispose.

But the diagnostic work? Let the agent handle that. Your time is better spent on the decisions that need context and judgment, not on copying debug output between terminal windows.

---

**Claims to verify:**

- Tidewave version ~0.5 (current as of writing; check hex.pm for latest)
- MCP specification release date (late 2024 from Anthropic)
- Tidewave initial release (April 2025)
- LiveView 1.1 debug options syntax
