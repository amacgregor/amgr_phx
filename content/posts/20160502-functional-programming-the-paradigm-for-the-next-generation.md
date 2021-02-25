%{
title: "Functional Programming: The Paradigm for the Next Generation",
category: 'Programming',
tags: ['programming','functional programming','software engineering','elixir'],
description: "Functional programming is often treated as the fad of hipster mustachioed programmers, and more often is dismissed without much consideration"
}
---

Functional programming is often treated as the fad of hipster mustachioed programmers, and more often is dismissed without much consideration; after all Object Oriented Programming is superior. Well, at least that use to be the trend but in recent years Functional programming has experienced a renaissance and as result functional programming languages are gaining more and more adoption.

But although functional programming is becoming more popular there is still a lot of friction and resistance to change specially when it comes to well seasoned OOP developers that are trying to make the transition, probably one of the best examples is the article titled [Functional Programming Is Not Popular Because It Is Weird.](https://probablydance.com/2016/02/27/functional-programming-is-not-popular-because-it-is-weird/) which starts with the following paragraph:

> Writing functional code is often backwards and can feel more like solving puzzles than like explaining a process to the computer. In functional languages I often know what I want to say, but it feels like I have to solve a puzzle in order to express it to the language. -- Malte Skarupke

As programmers we are trained to conceptualize and abstract problems in a certain way, our first instinct is to try and frame the problem using objects a concept all to familiar both inside and outside of programming.

Functional programming takes a different approach, one that might feel alien, strange and backwards to most programmers; one that forces us to leave state behind and embrace immutability, to favour recursion instead of loops, to leave what we know and adopt new patterns to solve old problems.

For some developers this is a huge change, one of herculean proportions; but I'm happy to say that is not a pointless one, quite the opposite there are many rewards and benefits to discover once you fully switch your mindset to think in a functional way.

## Functional Thinking

Functional Thinking? What do we mean by that exactly? Well, I could go into detail about what functional thinking is how writing _functional_ code is more than just the selection of the programming language but also affects how we design our code, how we structure reusable blocks of code, what trade-offs we accept and so on.

However, I believe the simplest way to clarify the concepts of functional programming and thinking is by comparing two solutions to the same problem, one solution using an imperative language and the other one using a functional language.

In this case I've selected two languages that I'm familiar with for the imperative language we will be using **PHP** and on the functional side we will use **Elixir**.

Let's start with a simple example, iterating through an array, adding each of the values and returning the sum. Let's start with the solution in PHP:

<iframe src='https://glot.io/snippets/ee2f163epo/embed' frameborder='0' scrolling='no' sandbox='allow-forms allow-pointer-lock allow-popups allow-same-origin allow-scripts' width='100%' height='450'></iframe>

Simple enough, by using the foreach loop we iterate across every single item in the array added to the sum integer and return the total, when its done. Let's take a look at the **Elixir** equivalent:

<iframe src='https://glot.io/snippets/ee2hjw0uer/embed' frameborder='0' scrolling='no' sandbox='allow-forms allow-pointer-lock allow-popups allow-same-origin allow-scripts' width='100%' height='450'></iframe>

Now, your initial reaction might be something like **_What in Knuts name is that?!_**, **_Why are there two declarations of the same function?!_**. If this is your first time seeing any **Elixir** code the above snippet might look awfully confusing and hardly making any sense.

But in reality it's actually very simple code, taking advantage of a common patter in FP and one of Elixir strongest features; pattern matching. Let's start by breaking down the code:

```elixir
defmodule SumModule do
```

Ok, nothing new to see here; this code might look familiar for anyone with previous experience with the Ruby programming which shouldn't be surprising considering the creator of the Elixir language was a long time contributor to the Ruby language.

Moving to the next two lines:

```elixir
def sum_list([]), do: 0
def sum_list([head|tail]), do: sum_list(tail) + head
```

Here is where the magic happens and where developers with no exposure to functional programming will get confused, how is it possible that we have 2 definition for the same function.

In elixir this technique is called pattern matching, and the code would read as follows:

- When function **sum_list()** is called with an empty list, return 0
- When function **sum_list()** is called with a non empty list, grab the first element of the list, call **sum_list()** with the remaining of the list, finally add the head value to the result

This technique is extremely common in elixir, handle each edge case in a separate function head. No need to worry about complicated control structures.

Now, I could argue the resulting code is cleaner and I dare to say more elegant, but before making statements like that, let's make our example more interesting, and change the array to the following values:

```php
$sumList = [5, 'four', 2, 'ten', 'one', 28, 6, 'five'];
```

Perfect, so now our code has to check if the value is a string or an integer and then convert the string representation into an integer for addition. To make things a little easier we are going add another array with integer values so we don't have to worry about the conversion.

<iframe src='https://glot.io/snippets/ee2f86mgj5/embed' frameborder='0' scrolling='no' sandbox='allow-forms allow-pointer-lock allow-popups allow-same-origin allow-scripts' width='100%' height='450'></iframe>

Well that does the trick but the code is definitively getting more complex and is no longer that easy to follow; let's take the same problem and solve it using elixir:

<iframe src='https://glot.io/snippets/ee37d6qn7u/embed' frameborder='0' scrolling='no' sandbox='allow-forms allow-pointer-lock allow-popups allow-same-origin allow-scripts' width='100%' height='450'></iframe>

In both cases the results are the same however, with elixir and pattern matching we get more compact code that doesn't rely on state, and instead used recursion with strong, well defined conditions. While the examples might not look overly complex and I'm sure they don't illustrate each language strongest features; they do serve the purpose of illustrating the difference in thinking methodologies and how each the paradigms approach a specific problem.

## Conclusion

In my opinion the benefits of functional programming are very real and valuable if only for the fact that introducing new paradigms to your problem solving toolbox can make you a better programmer; even if in the end you continue using an imperative language.
