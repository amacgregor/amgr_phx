%{
title: "Broadway In 5 Minutes",
category: "Programming",
tags: ["elixir","functional programming","broadway"],
description: "The basics of using broadway for elixir programming",
published: true
}
---

At its core, most applications are just moving data from one place to another. This is true for web applications, data processing applications, and even games. 

Yet as the developer seems, we are always reinventing the wheel. We are always trying to find the best way to move data from one place to another.

We have a few options for moving data from one place to another in the Elixir world. The most popular options are GenStage and Broadway.

Broadway is an open-source library with concurrent and fault-tolerant data ingestion pipelines. Build on top of GenStage; Broadway is a micro-framework for building production-ready Genstage pipelines.

Unlike GenStage, Broadway provides several useful features out of the box. These features include:

- Rate limiting
- Batching
- Automatic restarts
- Graceful shutdowns

## A Quick Example 


```elixir
Mix.install([
    {:broadway, "~> 1.0"}
])

# The producer -->
defmodule MyApp.Counter do
  use GenStage

  def start_link(number) do
    GenStage.start_link(Counter, number)
  end

  def init(counter) do
    {:producer, counter}
  end

  def handle_demand(demand, counter) when demand > 0 do
    events = Enum.to_list(counter..counter+demand-1)

    {:noreply, events, counter + demand}
  end
end

# The transformer -->
defmodule MyApp.CounterMessage do
  def transform(event, _opts) do
    message = %Broadway.Message{
      data: event,
      acknowledger: {__MODULE__, :ack_id, event}
    }
  end

  def ack(_ref, _successes, _failures) do
    :ok
  end
end

# The main module -->
defmodule MyApp do
  use Broadway

  alias Broadway.Message

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: MyAppExample,
      producers: [
        default: [
          module: {MyApp.Counter, 0},
          transformer: {MyApp.CounterMessage, :transform, []},
          stages: 1
        ]
      ],
      processors: [
        default: [stages: 2]
      ],
    )
  end

  def handle_message(:default, %Message{data: data} = message, _context) do
    Process.sleep 1000

    message
    |> IO.inspect
  end
end

```

## Resources 

- [Broadway Documentation](https://hexdocs.pm/broadway/Broadway.html)
- [How to use Broadway in Elixir](https://www.bignerdranch.com/blog/how-to-use-broadway-in-elixir/)
- [How to use Broadway in your Elixir application](https://blog.appsignal.com/2019/12/12/how-to-use-broadway-in-your-elixir-application.html)