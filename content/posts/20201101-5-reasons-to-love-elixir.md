%{
title: "5 Reasons to love Elixir",
category: "Programming",
tags: ["functional programming","programming","elixir"],
description: "Five reasons that will make you love the Elixir language and stack if you don't already"
}
---

<!--Five reasons that will make you love the Elixir language and stack if you don&#x27;t already-->

Whenever I have a new side project idea, the need to build a quick prototype or even opportunity to build something from scratch at at work, I keep coming back to [Elixir](https://publish.obsidian.md/allanmacgregor/Programming+Languages/Elixir/Elixir) time and time again.

Elixir has a strong pull on me, and not without reason. The language creators have done an exceptional job at building not only a fantastic language but also a thriving ecosystem.

The following 5 are some of the reasons why I keep coming back to Elixir.

## Mix

Mix is a build tool that ships with Elixir and provides tasks for creating, compiling, testing, debugging, managing dependencies and much more.

Mix is comparable to tools like `rake` or `artisan` if you are coming from the **Ruby** and **PHP** worlds respectively

#### Creating a new project

```bash
mix new myproject
```

Running that command will generate our new project with the boilerplate structure and necessary files. The output will look something like

```bash
- creating README.md
- creating .formatter.exs
- creating .gitignore
- creating mix.exs
- creating lib
- creating lib/myproject.ex
- creating test
```

The most important file that is generated is our `mix.exs` file which contains the configuration for our application, dependencies, environments and the current version. The file might look something like this:

```elixir
defmodule Myexample.Mixfile do
  use Mix.Project

  def project do
    [
      app: :myexample,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end
end
```

Overall, mix is really powerful and easy to extend; and is one of the reasons why using elixir is so friendly to new developers.

### Additional Resources

- [Elixir School: Mix](https://elixirschool.com/en/lessons/basics/mix/)
- [Introduction to Mix](https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html)

## Credo and Dialyxir

**Credo** is a static code analyzer for elixir, that has a very particular focus on teaching and building code consistency.

![Credo Example](/images/posts/credo-example.png)

**Dialyxir** is a mix wrapper for [Erlang](https://publish.obsidian.md/allanmacgregor/Programming+Languages/Erlang/Erlang) Dialyzer; which is another tool for static code analysis.

```elixir
$ mix dialyzer
...
examples.ex:3: Invalid type specification for function 'Elixir.Examples':sum_times/1.
The success typing is (_) -> number()
...
```

While both tools are static analysers they fill different needs and offer different kinds of insights into our code.

**Credo** is better suited to see of our code follows the common **'good' code practices** accepted by the community; while Dialyxir on the other hand let us catch things like **type errors** and unreachable code.

### Additional Resources

- [Credo](https://github.com/rrrene/credo)
- [Dialyxir](https://github.com/jeremyjh/dialyxir)

## Processes

One of Elixir's biggest selling points is the concurrency support, and the scalability and fault tolerance that comes with it; at the core of this concurrency model we have elixir processes.

**Processes** in the context of elixir are not the same as operating system processes, elixir processes are incredibly lightweight in comparision and can be describe as having the following characteristics:

- isolated from each other
- run concurrent to one another
- communicate via message passing
- run inside of the Erlang VM

Process can be created and spawn directly like:

```elixir
pid = spawn fn -> 1 + 3 end
```

Which all it does it spawns a process to execute the anonymous function; to more complex uses cases with message passing and supervision trees. One of the main abstractiosn that builds upon these processes is **Tasks**.

**Tasks** which provide better error reporting and introspection:

```elixir
iex(1)> Task.start fn -> raise "oops" end
{:ok, #PID<0.55.0>}

15:22:33.046 [error] Task #PID<0.55.0> started from #PID<0.53.0> terminating
** (RuntimeError) oops
    (stdlib) erl_eval.erl:668: :erl_eval.do_apply/6
    (elixir) lib/task/supervised.ex:85: Task.Supervised.do_apply/2
    (stdlib) proc_lib.erl:247: :proc_lib.init_p_do_apply/3
Function: #Function<20.99386804/0 in :erl_eval.expr/5>
    Args: []
```

Tasks are incredibly handy and enable us to run work both synchronously with `Task.await/1` and asynchronously with `Task.async/1`

### Additional Resources

- [Processes](https://elixir-lang.org/getting-started/processes.html)
- [Intro to Processes in Elixir](https://teamgaslight.com/blog/intro-to-processes-in-elixir)

## The Syntax

Elixir syntax is one of its main appeals; and at times you can clearly see the **Ruby** influence in the language and the clear focus on developer happiness and usability.

```elixir
defmodule Article do
    defp read(:content, [paragraph | article]), do: read({:content, article})
    defp read(:content, []), do: {:done, []}

    def read_article() do
        {:done, _} = read({:content, get_article()})
        for _ <- 1..10, do: something()
    end
end
```

But looking at the snippet above makes it clear that while syntax is highly readable this is not Ruby, there are a couple things happening in the code above:

- mix of inline and fully expanded functions
- multiple function heads with pattern matching
- simple recursion
- function parameter decomposition

Elixir, in my opinion can pack a lot of expressiveness into a very small amount of code that is also highly readable.

### Additional Resources

- [Elixir Crash Course](https://elixir-lang.org/crash-course.html)
- [Elixir Syntax Reference](https://hexdocs.pm/elixir/syntax-reference.html)

## Phoenix Framework

> Phoenix is a web development framework written in the functional programming language Elixir. Phoenix uses a server-side model-view-controller pattern. Based on the Plug library, and ultimately the Cowboy Erlang framework, it was developed to provide highly performant and scalable web applications. - [wikipedia](https://en.wikipedia.org/wiki/Phoenix_(web_framework))

Saving the best for last we have the **Phoenix Framework**, which often gets compared to the Laravel or Ruby on rails; but in my honest opinion is much much better.

Frameworks like **RubyOnRails** and **Laravel** suffer of a capital sin, there is too much freaking automagic. By this I mean those frameworks try to abstract too much and hide too much complexity to the point where they become more of a hindrance in certain scenarios.

Phoenix, has the right amount of scaffolding and abstractions without taking anything away from your control. Getting a Phoenix project up and running is easy as:

```bash
$ mix archive.install hex phx_new
$ mix phx.new demo --live
```

### Phoenix Liveview

> Phoenix LiveView is an exciting new library which enables rich, real-time user experiences with server-rendered HTML.

LiveView enables developers to build realtime interactive apps **without** touching any Javascript; it's all done with server side logic.

### Additional Resources

- [Phoenix Overview](https://hexdocs.pm/phoenix/overview.html)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
