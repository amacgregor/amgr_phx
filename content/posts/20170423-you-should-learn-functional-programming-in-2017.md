%{
title: "You Should Learn Functional Programming in 2017",
category: 'Programming',
tags: ['programming','functional programming','software architecture','elixir'],
description: "Functional programming is making a big comeback and here is why developers should make their mission for 2017 to learn a functional language"
}
---

Functional programming has been around for a very long time, starting in the 50's with the introduction of the **Lisp** programming language; and if you been paying attention in the last two years languages like **Clojure**, **Scala**, **Erlang**, **Haskell** and **Elixir** have been making a lot of noise and getting tons of attention.

But what is **functional programming**, why is everyone going crazy about it and why the heck are not more people using it? In this post, I will attempt to answer all of those questions and hopefully pique your interested on the idea of functional programming.

## A Brief History of Functional Programming

As we said before functional programming started back in the 50's with the creation of Lisp to run in the **IBM700/7000 series of scientific computers**. Lisp introduced many paradigms and features that we associate with functional programming now days, and while we can call **Lisp** the granddaddy of functional programming we can even further to a common root between all functional programming languages, **Lambda Calculus**.

![Ahh the good ole days](https://upload.wikimedia.org/wikipedia/commons/b/b9/NASAComputerRoom7090.NARA.jpg)

This is by far the most interesting aspect of functional programming; all functional programming languages are based on the same simple mathematical foundation, **Lambda Calculus**.

> Lambda calculus is Turing complete, that is, it is a universal model of computation that can be used to simulate any single-taped Turing machine.[1] Its namesake, the Greek letter lambda (λ), is used in lambda expressions and lambda terms to denote binding a variable in a function. -- [Wikipedia](https://en.wikipedia.org/wiki/Lambda_calculus#Explanation_and_applications)

Lambda Calculus is a surprisingly simple yet powerful concept. At the core of lambda calculus we have two concepts:

- **Function abstraction**, which is used to generalize expressions through the introduction of names (variables).
- **Function application**, which is used to evaluate the generalized expressions by giving names to particular values.

Let's take a look at an example, a single argument function _f_ that increments the argument by one:

```
f = λ x. x+1
```

Let's say we want to apply the function to the number 5; then the function can be read as follows:

```
f(5) => 5 + 1
```

## Functional Programming Fundamentals

Enough Math, for now, lets take a look at the features that make Functional programming a powerful concept:

### First-Class Functions

In functional languages, functions are first-class citizens this means that **a functions can be stored in a variable**, for example in elixir that would look like this:

```
double = fn(x) -> x * 2 end
```

And as such we can easily call the function as follows:

```
double.(2)
```

### High-Order Functions

A high order function is defined as a function that takes one or more functions as arguments and/or that returns a new function. Let's use our double function again to exemplify the concept:

```
double = fn(x) -> x * 2 end
Enum.map(1..10, double)
```

In this case **Enum.map** takes an enumerable –a list– as the first argument and the function we just defined as the second; and **applies the function** to each element in the enumerable the result being:

```
[2,4,6,8,10,12,14,16,18,20]
```

### Immutable State

In functional programming languages state is immutable, this means that once a variable has been bound to **a value they cannot be redefined**, this has the nice advantage of **preventing side effects and race conditions**; making concurrent programming much much easier.

As before let's use Elixir to illustrate this concepts:

{% highlight elixir %}
iex> tuple = {:ok, "hello"}
{:ok, "hello"}
iex> put_elem(tuple, 1, "world")
{:ok, "world"}
iex> tuple
{:ok, "hello"}
{% endhighlight %}

In the example our tuple will never change values, in the third line put_elem is returning a completely new tuple without modifying the values of the original.

I won't go into further details because this post is not an introduction to lambda calculus, computing theory or even functional programming; if you would like me to dig deeper on either subject drop me a message on the comment section. For now our take away from this section is the following:

- Functional Programming has been around for a long time (the early 50's)
- Functional Programming is based on mathematical concepts, specifically Lambda Calculus
- Functional Programming was deemed too slow compared to imperative languages
- Functional Programming is making a comeback.

<script async src="//pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>

<ins class="adsbygoogle"
     style="display:block; text-align:center;"
     data-ad-layout="in-article"
     data-ad-format="fluid"
     data-ad-client="ca-pub-6937861309533018"
     data-ad-slot="9206842858"></ins>

<script>
     (adsbygoogle = window.adsbygoogle || []).push({});
</script>

## Functional Programming Applications

As software developers we are living in exciting times, the promise of the cloud is finally here, and with it, an unprecedented amount of computer power is available to every single one of us. Unfortunately, with there also came demands of scalability, performance, and concurrency.

**Objected Oriented Programming** is simply not cutting it anymore, specially when it comes to **concurrency** and **parallelism**; trying to add concurrency and parallelism to this languages adds lots of complexity and more often than not leads to **over engineering and poor performance.**

Functional programming in the other hand is already well suited for these challenges, **Immutable state, Closures, and High order functions**, concepts that lend themselves very well for writing highly concurrent and distributed applications.

But don't take my word for it, you can find enough proof by looking at the technological feeds of startups like WhatsApp and Discord:

- [WhatsApp](https://www.wired.com/2015/09/whatsapp-serves-900-million-users-50-engineers/) was able to support 900 million users with only **50 engineers** in their team by using **Erlang**.
- [Discord](https://blog.discordapp.com/how-discord-handles-push-request-bursts-of-over-a-million-per-minute-with-elixirs-genstage-8f899f0221b4) in similar fashion handles over a **million requests per minute** using **Elixir**.

These companies and teams are capable of handling this massive growth thanks to the advantages of functional programming, and as functional programming gains more and more traction; I strongly believe this stories like the WhatsApp and Discord will become more and more common.

For that reason functional programming needs to be a must on every developer’s toolbox of knowledge, you need to be ready to build the **next generation of applications** that will serve the **next billion of users**; and heck if that wasn't enough trust me functional programming is really fun, just take a look at **Elixir**:

- [Introduction to Elixir](https://elixir-lang.org/getting-started/introduction.html)
- [Learn Elixir the fun way](https://rob.conery.io/2016/01/04/learn-elixir-while-having-fun/)
- [4 Reasons We're Having Fun Programming Elixir](https://teamgaslight.com/blog/4-reasons-were-having-fun-programming-elixir)

Finally, If you have any comments, corrections or would you like to know more about the subject don't hesitate to leave a comment just below.
