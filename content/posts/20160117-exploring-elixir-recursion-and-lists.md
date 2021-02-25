%{
title: "Exploring Elixir Recursion and Lists",
category: 'Programming',
tags: ['elixir','functional programming'],
description: "Exploration of recursion in elixir with lists"
}
---

Recently, I've been playing with a new language called [Elixir](https://elixir-lang.org/). Elixir is a **functional programming language** specifically designed with the intention of creating scalable and maintainable applications.

As many developers my main experience with programming languages and paradigms has been with **object oriented programming**; functional programming is a completely different beast and as I explore and learn more, the more fascinating I find the promises and ideas behind functional programming.

One of the things that has been messing with my head considerably is the fact that functional programming relies heavily on recursion. Now, technically speaking elixir is not a purely functionaly language and the way they implement **immutability** is a bit different; that being said in elxir as in any other functional programming language **there are no loops**.

No loops!? no **foreach**, no **for**, no **while** instead we get recursion; where a function gets called recursively until a condition is reached that stops the recursive action from ocurring again — for example processing each element in a list until the list is empty.

Sounds confusing right? Let's look at an example:

<script src="https://gist.github.com/amacgregor/93b23d7260b62a0b72e5.js"></script>

The previous code is part of an exercise I did for [Exercism.io](https://exercism.io) that required to reimplement the functionality of the native List module; the count function will take a list of numbers and return a count of the elements inside the list.

If this is the first time you look at elixir the first thing to jump at you is that it seems we are defining the count function twice; this is not a mistake and is one of the most amazing features of the elixir language, it's called **pattern matching** I won't into detail on how that works on this post but suffice to say that the first definition will only be called if we recieve an empty list.

Back to recursion, let's take a look at the second defintion of the function:

```elixir
  def count([_|tail]) do
    count(tail) + 1
  end
```

All we are doing at this point is taking out the first element of the list passing it to the count function and returning the **result + 1** on every single instance, but how does that work exactly let's break it down assuming we pass **[1,2,3,4,5]** as parameter:

```elixir
count([1,2,3,4,5])                           #returns 4 + 1
  "this in turn calls" -> count([2,3,4,5])   #returns 3 + 1
  "this in turn calls" -> count([3,4,5])     #returns 2 + 1
  "this in turn calls" -> count([4,5])       #returns 1 + 1
  "this in turn calls" -> count([5])         #returns 0 + 1
  "this in turn calls" -> count([])          #returns 0
```

This is a very simple example of the power of recursion but illustrates the concept very well. For now the most imporant thing about recursion is that we don't need mutable state while iterating through a list of values — a.k.a solving a problem.
