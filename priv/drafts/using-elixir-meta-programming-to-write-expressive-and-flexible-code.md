%{
title: "Using Elixir Meta Programming To Write Expressive And Flexible Code",
category: "Programming",
tags: ["elixir","functional programming","programming","meta-programming"],
description: "Elixir functional programming programming meta programming",
published: false
}
---

<!--Elixir's metaprogramming system is not a parlor trick — it is the machinery underneath every Phoenix controller, every Ecto schema, and every ExUnit test you have ever written-->

Every Phoenix controller you have ever written is powered by metaprogramming. Every Ecto schema. Every `test "something works"` block in ExUnit. You are already a consumer of Elixir's macro system whether you realize it or not.

Most metaprogramming tutorials start with toy examples and end before they get useful. This article takes a different approach. We are going to start with the foundational mechanics — how Elixir represents code as data — and build up to real, working macro systems that mirror what Phoenix and Ecto do under the hood. By the end, you will understand not just *how* macros work, but *when* to reach for them and, more importantly, when not to.

## Code Is Data: The AST

Elixir inherited a critical insight from Lisp: code can be represented as a data structure that the language itself can manipulate. In Elixir, that data structure is a simple three-element tuple.

You can see it for yourself using `quote`:

```elixir
iex> quote do: 1 + 2
{:+, [context: Elixir, imports: [{1, Kernel}, {2, Kernel}]], [1, 2]}
```

That tuple follows a consistent format: `{atom, metadata, arguments}`. The first element is the operation (an atom or a function name). The second is a keyword list of metadata — line numbers, context, imports. The third is the list of arguments.

This format is called the **Abstract Syntax Tree**, or AST. Every piece of Elixir code, no matter how complex, reduces to nested combinations of this 3-tuple.

Let's look at something more involved:

```elixir
iex> quote do
...>   def hello(name) do
...>     "Hello, #{name}"
...>   end
...> end
{:def, [context: Elixir, imports: [{1, Kernel}, {2, Kernel}]],
 [{:hello, [context: Elixir], [{:name, [], Elixir}]},
  [do: {:<<>>, [],
    ["Hello, ", {:"::", [],
      [{:name, [], Elixir}, {:binary, [], Elixir}]}]}]]}
```

It looks dense. But the structure is mechanical and predictable. Every node is a 3-tuple. Every leaf is a literal (numbers, atoms, strings) or a variable reference. There is no magic here — just recursive data.

This is the foundation that makes everything else possible. Because Elixir code is *just data*, we can write functions that receive code, transform it, and return new code. Those functions are called macros.

### Unquote: Injecting Values into the AST

If `quote` converts code into its AST representation, `unquote` does the reverse — it injects a value *into* a quoted expression. Think of `quote` as creating a template and `unquote` as filling in the blanks.

```elixir
iex> name = :world
iex> quote do: "Hello, " <> unquote(Atom.to_string(name))
{:<>, [context: Elixir, imports: [{2, Kernel}]],
 ["Hello, ", "world"]}
```

Without `unquote`, the variable `name` inside the `quote` block would refer to a *quoted variable* — an AST node representing the variable, not its value. `unquote` evaluates the expression in the caller's context and splices the result into the AST.

This distinction matters. It is the difference between generating code that *references* a variable and generating code that *embeds* a computed value.

There is also `unquote_splicing`, which injects a list of elements into an AST list:

```elixir
iex> args = [1, 2, 3]
iex> quote do: sum(unquote_splicing(args))
{:sum, [], [1, 2, 3]}
```

These three primitives — `quote`, `unquote`, and `unquote_splicing` — are the entire vocabulary of Elixir's code generation system. Everything else is built on top of them.

## Your First Macro

A macro is a function that runs at compile time and returns an AST. The compiler takes that returned AST and inserts it in place of the macro call. That is the entire mental model.

Let's start with something simple — a macro that logs an expression along with its result:

```elixir
defmodule Debug do
  defmacro log(expression) do
    quote do
      result = unquote(expression)
      IO.puts("#{unquote(Macro.to_string(expression))} => #{inspect(result)}")
      result
    end
  end
end
```

Usage:

```elixir
iex> require Debug
iex> Debug.log(1 + 2)
# Prints: 1 + 2 => 3
3
```

Notice what happened. At compile time, `Debug.log(1 + 2)` received the *AST* of `1 + 2` — not the value `3`. The macro then generated code that evaluates the expression, prints the original source alongside the result, and returns the value.

This is fundamentally different from a function call. A function receives evaluated arguments. A macro receives unevaluated AST. That distinction is the source of all of metaprogramming's power and all of its danger.

### A More Practical Macro: Timing Execution

Let's build something you might actually use — a macro that times how long a block of code takes to execute:

```elixir
defmodule Benchmark do
  defmacro measure(label, do: block) do
    quote do
      start = System.monotonic_time(:microsecond)
      result = unquote(block)
      elapsed = System.monotonic_time(:microsecond) - start
      IO.puts("[#{unquote(label)}] Completed in #{elapsed} microseconds")
      result
    end
  end
end
```

```elixir
iex> require Benchmark
iex> Benchmark.measure "sorting" do
...>   Enum.sort(1..10_000 |> Enum.shuffle())
...> end
# Prints: [sorting] Completed in 1523 microseconds
[1, 2, 3, ...]
```

The macro receives the `do` block as an AST, wraps it with timing logic, and returns the combined AST to the compiler. At runtime, the timing code executes seamlessly around the original block. Zero abstraction overhead — the generated code is exactly what you would have written by hand.

## Building a Real DSL: A Validation Framework

Toy examples are fine for learning mechanics. Let's build something that mirrors how real Elixir libraries work — a compile-time validation DSL using `Module.register_attribute` and `@before_compile`.

The goal: define a module where you can declare validation rules in a readable, declarative syntax, and have the system generate a `validate/1` function at compile time.

```elixir
defmodule Validator do
  defmacro __using__(_opts) do
    quote do
      import Validator, only: [validate_field: 2, validate_field: 3]
      Module.register_attribute(__MODULE__, :validations, accumulate: true)
      @before_compile Validator
    end
  end

  defmacro validate_field(field, type, opts \\ []) do
    quote do
      @validations {unquote(field), unquote(type), unquote(opts)}
    end
  end

  defmacro __before_compile__(env) do
    validations = Module.get_attribute(env.module, :validations)

    clauses =
      Enum.map(validations, fn {field, type, opts} ->
        build_validation(field, type, opts)
      end)

    quote do
      def validate(data) do
        errors =
          unquote(clauses)
          |> Enum.map(fn check -> check.(data) end)
          |> Enum.reject(&is_nil/1)

        case errors do
          [] -> {:ok, data}
          errors -> {:error, errors}
        end
      end
    end
  end

  defp build_validation(field, :required, _opts) do
    quote do
      fn data ->
        case Map.get(data, unquote(field)) do
          nil -> {unquote(field), "is required"}
          "" -> {unquote(field), "is required"}
          _ -> nil
        end
      end
    end
  end

  defp build_validation(field, :format, opts) do
    pattern = Keyword.fetch!(opts, :pattern)

    quote do
      fn data ->
        value = Map.get(data, unquote(field))

        if value && !Regex.match?(unquote(Macro.escape(pattern)), to_string(value)) do
          {unquote(field), "has invalid format"}
        end
      end
    end
  end

  defp build_validation(field, :length, opts) do
    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, :infinity)

    quote do
      fn data ->
        value = Map.get(data, unquote(field))

        cond do
          is_nil(value) ->
            nil

          String.length(to_string(value)) < unquote(min) ->
            {unquote(field), "must be at least #{unquote(min)} characters"}

          unquote(max) != :infinity and
              String.length(to_string(value)) > unquote(max) ->
            {unquote(field), "must be at most #{unquote(max)} characters"}

          true ->
            nil
        end
      end
    end
  end
end
```

Now the consumer code reads like a specification:

```elixir
defmodule UserValidator do
  use Validator

  validate_field :name, :required
  validate_field :name, :length, min: 2, max: 100
  validate_field :email, :required
  validate_field :email, :format, pattern: ~r/@/
end
```

```elixir
iex> UserValidator.validate(%{name: "A", email: "test@example.com"})
{:error, [{:name, "must be at least 2 characters"}]}

iex> UserValidator.validate(%{name: "Allan", email: "test@example.com"})
{:ok, %{name: "Allan", email: "test@example.com"}}
```

Let's break down the machinery at work.

**`Module.register_attribute/3`** with `accumulate: true` creates a module attribute that collects values instead of overwriting them. Every time `validate_field` is called, it pushes a tuple onto the `@validations` list. This accumulation happens at compile time.

**`@before_compile`** registers a callback that fires after all module attributes have been set but before the module is compiled into BEAM bytecode. This is where we read the accumulated validations and generate the `validate/1` function.

The result is a function that exists in the compiled module as if you had written it by hand. No runtime interpretation. No reflection. Just plain, fast, pattern-matched Elixir code generated from declarative specifications.

## How the Ecosystem Uses Macros: `use` and `__using__/1`

The `use` keyword is Elixir's standard mechanism for macro-based code injection. When you write `use SomeModule`, the compiler calls `SomeModule.__using__/1` and injects the returned AST into your module.

This is how Phoenix, Ecto, and ExUnit set up their modules.

### Phoenix Controllers

When you write:

```elixir
defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
```

The `use MyAppWeb, :controller` call invokes a `__using__/1` macro that injects imports for `Plug.Conn`, `Phoenix.Controller`, and your application's router helpers. Without macros, every controller would need a dozen `import` and `alias` lines at the top. The macro eliminates that boilerplate.

### Ecto Schemas

```elixir
defmodule MyApp.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string
    field :email, :string
    timestamps()
  end
end
```

The `schema` macro uses `Module.register_attribute` internally to accumulate field definitions. Each `field` call adds metadata to the module's attribute list. At compile time, Ecto generates the struct definition, type specifications, and reflection functions (`__schema__/1`, `__schema__/2`) that power query building and changeset validation.

### ExUnit

```elixir
defmodule MyApp.UserTest do
  use ExUnit.Case

  test "greets the world" do
    assert 1 + 1 == 2
  end
end
```

The `test` macro converts the string description and do-block into a uniquely named function that ExUnit's test runner can discover and execute. The `assert` macro captures the original expression so that on failure, it can report *what* failed — not just *that* something failed.

This pattern — `use` injecting macros, macros accumulating metadata, `@before_compile` generating functions — is the backbone of Elixir's ecosystem. Understanding it transforms your reading of library source code from bewilderment to clarity.

## Compile-Time vs. Runtime Code Generation

One of Elixir's strongest design decisions is that macros expand at compile time. The generated code is verified by the compiler, optimized alongside the rest of your module, and runs as native BEAM bytecode.

This is fundamentally different from runtime metaprogramming in languages like Ruby or Python, where `define_method` or `setattr` modify objects while the program is running. Runtime metaprogramming is flexible but incurs costs: performance overhead on every call, difficulty with static analysis, and error messages that trace to generated code rather than its source.

Elixir's compile-time approach eliminates these costs. Once your module is compiled, there is no trace of macros in the BEAM bytecode. The compiler has already expanded everything. What remains is ordinary function calls and pattern matches.

You can verify this yourself using `Macro.expand/2` in IEx to see exactly what a macro generates before compilation:

```elixir
iex> ast = quote do: if(true, do: "yes", else: "no")
iex> Macro.expand(ast, __ENV__) |> Macro.to_string() |> IO.puts()
```

This transparency is a debugging superpower. When a macro produces unexpected behavior, you can inspect its expanded output and reason about it as plain Elixir code.

There are cases where you genuinely need runtime code generation — `Code.eval_string/1` exists for this purpose. But reaching for it should feel like pulling a fire alarm. If you need runtime code generation in Elixir, you have almost certainly made a wrong turn somewhere.

## When NOT to Use Macros

Macros are a power tool with a sharp edge. The Elixir community has a well-earned rule of thumb: **if a function can do the job, use a function**.

Here is why.

### The Debugging Tax

When a macro generates code, stack traces point to the generated code, not the macro definition. If the generated code is complex, debugging becomes an archaeological expedition — you are reading code that nobody wrote by hand, trying to reconstruct the macro logic that produced it.

Functions, by contrast, have clean stack traces. They compose predictably. They are visible to dialyzer and other static analysis tools.

### Macro Hygiene

Elixir macros are **hygienic** by default. Variables defined inside a macro do not leak into the caller's scope, and vice versa. This is a massive improvement over C preprocessor macros, which are textual substitutions with no scoping rules whatsoever.

```elixir
defmacro hygienic_example do
  quote do
    x = 42
  end
end
```

If a caller already has a variable named `x`, the macro's `x` will not overwrite it. They exist in separate scopes.

However, you can break hygiene intentionally with `var!`:

```elixir
defmacro set_name(value) do
  quote do
    var!(name) = unquote(value)
  end
end
```

This injects a variable directly into the caller's scope. It is occasionally necessary for DSLs but should trigger immediate scrutiny. Every use of `var!` is a potential source of confusing behavior.

### The Decision Framework

Reach for a macro only when you need one of these capabilities that functions cannot provide:

1. **Compile-time code generation** — accumulating definitions and generating functions before the module is compiled.
2. **AST access** — you need the unevaluated syntax tree of an expression, not its result. The `assert` macro in ExUnit is the canonical example.
3. **Custom syntax** — you are building a DSL where the calling syntax would be impossible or unreadable as a function call.

If none of these apply, write a function. Your future self will thank you, and so will the next developer who reads your code.

## Putting It All Together

Elixir's metaprogramming system is built on a remarkably small set of primitives. The AST is a 3-tuple. `quote` converts code to AST. `unquote` injects values into AST. `defmacro` defines functions that return AST to the compiler. `Module.register_attribute` accumulates metadata at compile time. `@before_compile` fires a callback to generate code from that metadata.

That is the entire system. Six concepts. Everything else — Phoenix's router DSL, Ecto's schema definitions, ExUnit's test declarations — is built from these same six pieces, composed in different ways.

The real mastery is not in knowing *how* to write macros. It is in knowing *when*. The best macro is the one that makes your domain logic read like a specification, where the gap between what the code *says* and what it *does* shrinks to zero. The worst macro is the one that saves three lines of typing and costs three hours of debugging.

Metaprogramming is not a daily tool. It is a force multiplier you deploy when you find a recurring pattern that cannot be adequately captured by functions alone. Used with that discipline, it produces some of the most expressive and maintainable code in any language ecosystem.

Use it like a scalpel. Not a machete.

---

### Further Reading

- [Elixir Official Guide: Meta-programming](https://hexdocs.pm/elixir/meta-programming.html)
- [Metaprogramming Elixir by Chris McCord](https://pragprog.com/titles/cmelixir/metaprogramming-elixir/)
- [Macro Source Code in Elixir Core](https://github.com/elixir-lang/elixir/blob/main/lib/elixir/lib/kernel.ex)
- [Saša Jurić: Understanding Elixir Macros](https://www.theerlangelist.com/article/macros_1)
