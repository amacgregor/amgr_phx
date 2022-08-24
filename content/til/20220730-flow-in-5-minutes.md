%{
title: "Flow In 5 Minutes",
category: "Programming",
tags: ["elixir","functional programming","flow"],
description: "The basics of using flow for elixir programming",
published: true
}
---

At its core, most applications are just moving data from one place to another. This is true for web applications, data processing applications, and even games. 

Yet as the developer seems, we are always reinventing the wheel. We are always trying to find the best way to move data from one place to another.

We have a few options for moving data from one place to another in the Elixir world.

Flow is a library that allows developers to express computations on collections, with the main difference being that they will be executed in parallel leveraging GenStage.


### A Quick Example 

Here is a quick example of how to use Flow to count the words in a file.

```elixir
File.stream!("path/to/some/file")
|> Flow.from_enumerable()
|> Flow.flat_map(&String.split(&1, " "))
|> Flow.partition()
|> Flow.reduce(fn -> %{} end, fn word, acc ->
  Map.update(acc, word, 1, & &1 + 1)
end)
|> Enum.to_list()
```

## Resources 

- [Flow Documentation](https://hexdocs.pm/flow/Flow.html)
- [A real-world introduction to Flow](https://blog.joelabshier.com/%F0%9F%8C%8A-a-realworld-introduction-to-elixir-flow/)