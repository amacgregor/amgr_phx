%{
title: "The AI-Native Elixir Project: What Changes When the Agent is Your Pair",
category: "Programming",
tags: ["elixir", "ai", "project-structure", "developer-workflow", "coding-agents"],
description: "How project structure, tooling, and practices evolve when AI agents are central to development",
published: false
}
---

I stopped writing code three months ago. That's not quite accurate; I still write code, but the ratio has shifted. Where I used to spend 80% of my time typing and 20% reviewing, those numbers have inverted. The agent writes; I direct and verify.

This isn't a productivity story. It's an architecture story.

When an AI agent becomes your primary pair programmer, the shape of your project changes. Not the domain logic — that stays yours — but everything around it. The documentation you write. The directory structures you choose. The tooling you configure. All of it bends toward a new constraint: the agent needs to understand your project well enough to make useful contributions without breaking things.

I've been running this experiment on my Elixir projects for the past six months. What follows is what I've learned about structuring a codebase for effective human-agent collaboration.

## The Shift in Role

The first thing that changes is your identity. You stop being "the person who writes the code" and become "the person who shapes the system." This sounds abstract until you experience it.

Here's what a typical session looks like now. I describe what I want: "Add a new content type for book reviews, following the same pattern as the existing Blog module." The agent reads my project documentation; it examines the existing modules; it generates the new code. I review the output, catch the one place where it misunderstood the pattern, and ask for a revision. Twenty minutes later, I have working code that would have taken me two hours to write myself.

The productivity gain is real but secondary. The primary shift is cognitive. I'm no longer holding implementation details in my head while I type; I'm holding architectural constraints and reviewing whether generated code respects them. This is a different kind of thinking. More strategic, less tactical.

Some developers resist this transition. They feel diminished, like their craft is being outsourced. I understand the impulse; I felt it too. But I've come to see it differently. An architect isn't less valuable than a bricklayer — they're doing different work. The craft shifts from "how do I implement this elegantly" to "how do I specify this clearly enough that the implementation comes out elegant."

That specification work starts with project structure.

## Project Structure for Agent Navigation

Agents navigate codebases the way junior developers do: they read documentation, explore directory structures, and pattern-match against what they've seen before. This has implications.

### The CLAUDE.md File

Every project I work on now has a `CLAUDE.md` file at the root. This isn't documentation for humans — though humans can read it — it's documentation for the agent. Here's the structure I've settled on:

```markdown
# CLAUDE.md

## Project Overview
One paragraph explaining what this project does and its core technology choices.
Include links to any upstream projects it's based on.

## Commands
Every command the agent might need, with comments explaining what each does.
Group by purpose: setup, development, quality checks, tests, deployment.

## Architecture
Describe the major subsystems and how they connect.
Include the data flow for the most common operations.
Call out any unusual patterns or conventions.

## Key Dependencies
List non-obvious dependencies and why they're there.
If you're using a fork or custom version, explain why.

## Code Style Notes
Explain conventions that aren't enforced by tooling.
Call out complexity limits, naming conventions, file organization.
```

The key insight: agents read this file before they do anything else. If your CLAUDE.md is incomplete or misleading, every subsequent interaction suffers. I've found it worthwhile to spend an hour writing a good one; the investment pays back across hundreds of agent interactions.

### Directory Layout That Explains Itself

Elixir projects already have strong conventions here — `lib/`, `test/`, `config/` — but within those boundaries, your choices matter. I've started organizing modules to make the dependency graph visible from the directory structure alone.

```
lib/
  my_app/
    # Core domain - no external dependencies
    accounts/
      user.ex
      credentials.ex

    # Infrastructure - wraps external services
    infrastructure/
      email_sender.ex
      payment_gateway.ex

    # Application services - orchestration
    services/
      registration.ex
      billing.ex

  my_app_web/
    # Web layer - presentation only
    live/
    controllers/
    components/
```

When an agent sees this structure, it understands immediately: changes to `accounts/` shouldn't touch infrastructure; web layer code shouldn't contain business logic. These aren't enforced by the compiler, but the spatial organization makes violations obvious during review.

### Module Naming as Communication

I used to name modules based on what felt natural. Now I name them based on what communicates intent to a reader who has never seen the codebase. The difference is subtle but meaningful.

`MyApp.UserService` tells you nothing. What service? What does it do with users? `MyApp.Accounts.Registration` tells you everything: it's in the accounts domain, it handles registration. When the agent needs to add email verification, it knows exactly where to look.

This sounds obvious, but I see codebases every week with modules named `Utils`, `Helpers`, `Manager`, `Handler`. These names are worse than useless — they actively mislead agents (and humans) about what the code does.

## Documentation as Interface

In an AI-native project, documentation stops being optional. It becomes the interface through which the agent understands your intent.

### @moduledoc and @doc Are Required

I've started treating missing documentation as a code smell equivalent to missing tests. Every public module gets a `@moduledoc`; every public function gets a `@doc`. Not because a human will read them — though they might — but because the agent will.

```elixir
defmodule MyApp.Accounts.Registration do
  @moduledoc """
  Handles user registration flows.

  This module coordinates between the User schema,
  credential validation, and email verification.
  It does NOT handle authentication - see MyApp.Auth for that.
  """

  @doc """
  Creates a new user account with the given attributes.

  Returns `{:ok, user}` on success, `{:error, changeset}` on validation failure.
  Sends a verification email as a side effect.

  ## Examples

      iex> register_user(%{email: "test@example.com", password: "secret123"})
      {:ok, %User{}}
  """
  def register_user(attrs) do
    # implementation
  end
end
```

Notice what I'm documenting: not just what the function does, but what it explicitly doesn't do, what side effects it has, and what the return values mean. The agent uses all of this context when generating code that calls these functions.

### The "NOT" Pattern

I've developed a habit of documenting what modules and functions *don't* do. This seems redundant until you realize that agents, like humans, make assumptions based on names. If `Accounts.Registration` doesn't handle password resets, say so explicitly. Otherwise, the agent might reasonably add password reset logic there, and you'll spend your review time explaining why that's the wrong place.

### Typespecs as Contracts

Dialyzer and typespecs serve a dual purpose in AI-native projects. They're still useful for static analysis, but they're also documentation that agents can parse and respect.

```elixir
@spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
def register_user(attrs) do
  # ...
end
```

When an agent generates code that calls `register_user/1`, it knows from the typespec that it needs to handle both success and error tuples. Without the spec, it might generate code that only handles the happy path.

## Tooling Integration

The tooling around an AI-native project serves a different purpose than traditional tooling. It's not just catching your mistakes — it's catching the agent's mistakes before they reach production.

### MCP Servers for Runtime Introspection

I've been running [Tidewave](https://github.com/tidewave-ai/tidewave_phoenix) on my Phoenix projects. It exposes the running BEAM system to agents through the Model Context Protocol, letting them inspect processes, query ETS tables, and examine supervision trees without leaving the conversation.

The productivity impact is significant. Instead of me explaining "there's an ETS table called :cache that stores session data," the agent can inspect it directly. When debugging, instead of copying stack traces back and forth, the agent can query the process state itself.

This is still early-stage tooling; I've hit rough edges. But the direction is clear: agents work better when they can see the system, not just the code.

### CI/CD as Guardrails

My CI pipeline has gotten more aggressive since I started working with agents. The old pipeline ran tests and maybe a linter; the new one runs everything I can think of that might catch AI mistakes.

```yaml
# .github/workflows/ci.yml
jobs:
  quality:
    steps:
      - run: mix format --check-formatted  # Formatting
      - run: mix credo --strict             # Linting
      - run: mix dialyzer                   # Type checking
      - run: mix sobelow -i Config.HTTPS    # Security scanning
      - run: mix test --cover               # Tests with coverage
```

The key addition is Dialyzer. Type checking catches a class of errors that are common in AI-generated code: calling functions with the wrong argument types, mishandling return values, using undefined function heads. These are exactly the kinds of mistakes an agent makes when it pattern-matches against code it's seen in training but doesn't quite fit your specific context.

### Pre-commit Hooks as First Defense

I run quality checks in CI, but I also run them pre-commit. This catches problems before they enter the repository at all.

```bash
#!/bin/sh
# .git/hooks/pre-commit

set -e

echo "Running formatter..."
mix format --check-formatted

echo "Running Credo..."
mix credo --strict

echo "Running tests..."
mix test --max-failures 5

echo "All checks passed!"
```

The `--max-failures 5` flag is intentional. When an agent breaks something, it often breaks many things at once; there's no point running all 500 tests when the first 5 already tell you there's a problem.

### Dialyzer as Specification

I've started thinking of Dialyzer differently. It's not just a static analysis tool; it's a specification language that agents can understand and respect.

When I write `@spec process_order(Order.t()) :: {:ok, Receipt.t()} | {:error, atom()}`, I'm not just documenting for humans. I'm giving the agent a contract it can verify its output against. If the generated code doesn't match the spec, Dialyzer catches it.

This changes how I write specs. I used to be lazy — `@spec my_function(map()) :: any()` — because the overhead of precise types felt burdensome. Now I write precise types because the agent uses them as constraints on its output.

## The Review Protocol

Reviewing AI-generated code requires different attention than reviewing human code. Agents make different mistakes.

### Check for Hallucinated Functions

This is the most common failure mode I see. The agent generates code that calls a function that doesn't exist — often a function that *sounds* like it should exist based on the module name and context.

```elixir
# Agent-generated code
def process_payment(order) do
  PaymentGateway.charge_card(order.payment_method, order.total)
end
```

Does `PaymentGateway.charge_card/2` actually exist? Or did the agent invent it based on what it expected to find? Always verify that called functions exist and have the expected arities.

### Verify Pattern Matching Exhaustiveness

Agents sometimes generate pattern matches that don't cover all cases, especially when working with custom types.

```elixir
# Potentially incomplete
def handle_result({:ok, value}), do: value
def handle_result({:error, reason}), do: raise reason

# What about {:pending, _}? Does your system use that?
```

If your domain has custom result types beyond the standard `{:ok, _}` and `{:error, _}`, make sure the agent knows about them — and verify that generated code handles all cases.

### Error Handling Patterns

Agents default to the patterns they saw most often in training data. For Elixir, this often means they use `with` statements without proper `else` clauses, or they raise exceptions where returning error tuples would be more idiomatic for your codebase.

```elixir
# Common agent pattern - crashes on error
def create_account(attrs) do
  user = Accounts.create_user!(attrs)  # Raises on failure
  send_welcome_email(user)
  {:ok, user}
end

# What you probably wanted
def create_account(attrs) do
  with {:ok, user} <- Accounts.create_user(attrs),
       {:ok, _} <- send_welcome_email(user) do
    {:ok, user}
  end
end
```

Check whether the error handling matches your project's conventions, not just whether it "works."

### The Review Checklist

I keep a mental checklist for reviewing agent code:

1. **Do all called functions exist?** Check arities.
2. **Are patterns exhaustive?** Look for unhandled cases.
3. **Does error handling match project conventions?** Exceptions vs. tuples.
4. **Are there any obvious security issues?** User input handling, SQL queries.
5. **Does the code respect module boundaries?** Web layer calling domain directly?
6. **Are the tests actually testing the right thing?** Agents sometimes write tests that pass but don't verify behavior.

This takes about 5-10 minutes per significant code change. It's faster than writing the code myself; it's the bottleneck that remains after the agent does its work.

## What Doesn't Change

Not everything shifts when you adopt AI-native practices. Some things remain stubbornly, essentially human.

### Domain Knowledge

The agent doesn't know your business. It doesn't know that your payment processor has a weird quirk with international transactions, or that your users hate email verification, or that your biggest customer has a custom integration that breaks assumptions everywhere else in the codebase.

This knowledge lives in your head; the agent can't acquire it from documentation or code inspection. You remain the source of truth for "what should this system actually do."

### Architectural Decisions

Which patterns to use. Where to put the boundaries between modules. Whether to optimize for read performance or write consistency. These are judgment calls that require understanding tradeoffs in context — exactly the kind of reasoning agents struggle with.

I've tried asking agents to make architectural recommendations. The results are coherent but generic; they read like textbook advice rather than project-specific guidance. Architecture remains human work.

### Taste

This is the hardest to articulate but the most important. Taste is knowing when code is "good enough" versus when it needs more work. It's recognizing when a clever solution is actually too clever. It's understanding when to break the rules because the rules don't apply here.

Agents optimize for patterns; humans optimize for outcomes. The gap between those things is taste.

---

I don't know where this equilibrium settles. Six months ago, I thought agents would handle simple tasks while I handled complex ones; now I watch them write fairly sophisticated code while I handle integration and review. The line keeps moving.

What I do know: the projects that work well with agents are the ones where the human took time to make the project legible. Good documentation. Clear structure. Explicit conventions. These things always mattered for human collaboration; they matter more now.

The agent is your pair. How well it performs depends on how well you've set the stage.

---

**Claims to verify:**
- Tidewave MCP server functionality — check current capabilities
- Specific Dialyzer error detection patterns — may vary by version
- CI/CD configuration syntax — verify against current GitHub Actions spec
