%{
title: "Piping :ok tuples",
category: "Programming",
tags: ["elixir","functional programming","programming"],
description: "How to cleanly handle {:ok,_} tuples inside an elixir pipe"
}
---

<!--How to cleanly handle {:ok,_} tuples inside an elixir pipe-->

The pipe operator `|>` is probably my favorite part of the elixir language; programming, more often than not, it can get messy and confusing for people new to the language.

This is especially true when having to pipe functions that return an `{:ok, payload}` tuple; dealing with it can be tricky, but there are a few easy ways to do so:

- Use `with` rather than piping
- Use an exclamation mark version of the function if available
- Create a helper function that extracts the value and also deals with error
- Use an anonymous function in the pipe
- Pipe into elem/2

I found the last one most helpful, especially when dealing with the elixir DateTime library.

```elixir
    last_check =
      last_check
      |> DateTimeParser.parse_datetime()
      |> elem(1)
      |> DateTime.from_naive!("Etc/UTC")
```

### References

- [Pipe second tuple member](https://elixirforum.com/t/pipe-second-tuple-member/18698)
