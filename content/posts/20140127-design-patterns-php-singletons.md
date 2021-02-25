%{
title: "Design Patterns in PHP: Singletons",
category: 'Programming',
tags: ['PHP','Design Patterns','Programming'],
description: "The singleton pattern is useful when we need to make sure we only have a single instance of a class for the entire request lifecycle in a web application. This typically occurs when we have global objects (such as a Configuration class) or a shared resource (such as an event queue)."
}
---

The singleton pattern is used to restrict the instantiation of a class to a single object, which can be useful when only one object is required across the system.

<!-- Patterns are still patterns, poor usage that ends ineffective and complex code which makes them into anti-patterns -->

**Singletons** are designed to ensure there is a single (hence the name singleton) class instance and that is global point of access for it, along with this single instance we have global access and lazy initialization.

A basic Singleton implementation will look something like the following example:

<script src="https://gist.github.com/amacgregor/8660951.js"></script>

In the previous example all three variables will point to the same object. The first call will instantiate the object while any subsequent will only return the instantiated object.

> In computer programming, lazy initialization is the tactic of delaying the creation of an object, the calculation of a value, or some other expensive process until the first time it is needed.

Let's address elephant in the room, and talk about why **Singletons** are considered an Anti-pattern by many developers, although this is going to highly depend on the framework and language used; for PHP **Singletons** are almost universally considered an Anti-pattern.

<div class="notice notice-warning">
	<strong>Singletons</strong> are considered by many to be an anti-pattern, Anti-patterns are design solutions that are usually ineffective and present a high risk of being counter productive.
</div>

## Singletons the spawns from Hell?

If you have read about **Singletons** before you are probably wondering what the hell am I doing?

**Singletons** are evil, an Anti-pattern and should never be used! Well that's exactly what I want to address in this article; saying [Singletons are Evil!!](https://c2.com/cgi/wiki?SingletonsAreEvil) is not enough, we need to understand why **Singletons** shouldn't generally be avoided.

<!-- Add more information about why **Singletons** are evil -->

There are several reasons why **Singletons** are considered an Anti-pattern, let's take a look at some of those reasons:

### Single Responsibility Pattern

This first problem that we encounter when using **Singletons** is that their usage breaks the **Single Responsibility Principle**.

Singleton objects are responsible of both their purpose and controlling the number of instances the produce, while the **Single Responsibility Principle** states that:

> ... every class should have a single responsibility, and that responsibility should be entirely encapsulated by the class.

### Hidden dependencies

What are hidden dependencies and how is that relevant to **Singletons**?, well if you read my previous article on [Dependency Injection](https://coderoncode.com/2014/01/06/dependency-injection-php.html) we saw how to pass dependencies as parameters to a function.

Any parameters accepted by a function are called visible dependencies, on the other hand if a function requires something else to operate that is referred through a global variable -- read singleton -- then that dependency is considered hidden.

Now this presents because there is no way for a third party to know about this hidden dependencies without taking a look at the actual function implementation.

> A visible dependency is a dependency that developers can see from a class's interface. If a dependency cannot be seen from the class's interface, it is a hidden dependency. [jenkov.com](https://tutorials.jenkov.com/ood/understanding-dependencies.html#visiblehidden)

### Testing

Along with these problems we have an issue when trying to Unit Test our applications. Proper **Unit Tests** should run independently of things like database, Singletons make unit tests difficult if not impossible since they have a global state.

That means that a singleton will stick around between **Unit Tests** once its instantiated, this could and will cause tests to unexpectedly influence each other.

There are workarounds that take care of 'cleaning up' the singleton after each test is run, however I find this contra-productive and messy.

## It's not all bad, is it ?

They can't be all bad, can't they? Well let's try to argue in favor (sort of) of Singletons and some cases where they might be useful:

- **Debug Logging:** Almost all developers will agree that a way to debug logging should be available for every function and part of the code. A singleton could serve this purpose without harming readability, testability or maintainability.

- **Filesystem and Database Access:** The argument can be made for Singletons proving access to the filesystem and database, now this might work if you need a single global filesystem or database access point it trades flexibility and testability for modicum amount of convenience.

## Conclusion

**Singletons**, **Anti-patterns**, and patterns in general are not good or bad; what makes a Singleton an Anti-pattern is not the pattern itself but how often is **poorly implemented and how easy it is to do so.**

Any pattern can become and an **Anti-pattern** if incorrectly implemented, which happens often. That being said, when speaking of modern PHP and modern frameworks it is hard to make case in favor of **Singletons** and personally I don't see any advantages that out weight the many downsides that come with this pattern.

<div class="notice notice-warning">
	As a <strong>final note</strong> I understand that Singletons are a controversial and polarizing topic, if you have an opinion, would like to complement any of the points made in this article or even better make a case in favor I would love to hear your comments below.
</div>
