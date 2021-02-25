%{
title: "Playing with dependency injection in PHP",
category: 'Programming',
tags: ['php','dependency injection','design patterns','programming'],
description: "Dependency Injection is a software design pattern that allows avoiding hard-coding dependencies and makes possible to change the dependencies both at runtime and compile time."
}
---

**Dependency Injection** is a software design pattern that allows avoiding hard-coding dependencies and makes possible to change the dependencies both at runtime and compile time.

By using **Dependency Injection** we can write more maintainable, testable, and modular code. All projects have dependencies. The larger the project the more dependencies is it bound to have; now having a great number of dependencies is nothing bad by itself however how those dependencies are managed and maintained is.

**Dependency Injection** is not a new pattern and it has been commonly used on many languages like Java, but this pattern is somewhat new in the **PHP** world and it's gaining traction quickly thanks for frameworks like [laravel](https://laravel.com)

Let's exemplify these concepts by creating a pair of classes first without dependency injection and then rewriting the code to use the dependency injection pattern; since I'm primarily a **Magento** developer I'll be really original (wink, wink) and create a **Product** and a **StockItem** class.

<script src="https://gist.github.com/amacgregor/8275062.js"></script>

<script src="https://gist.github.com/amacgregor/8275059.js"></script>

At first glance the code looks pretty normal and it's what many PHP developers would call good code, however if we take a closer look at it using the **S.O.L.I.D** principle we can see that the code actually has many problems:

- The _StockItem_ is tightly coupled with the _Product_ class, and while this might not look bad on this particular example. Let's imagine that we made a change to the _StockItem_ class to include a new parameter, we would then have to modify every single class where the _StockItem_ object was created.

- The _Product_ class knows too much, in this case the stock status and quantity, let's say that our application can handle inventories from multiple sources and stores but for the same product. With that in mind it would be in our best interest to make the _Product_ class know less about its inventory.

- We just made our life harder when it comes to unit testing the code. Since we are instantiating the stockItem inside the constructor it would be impossible to unit test the _Product_ class without also testing the _StockItem_ class.

## Let's Inject something!

In the other hand by using dependency injection we can correct most of these problems, let's take at the same code but using dependency injection:

<script src="https://gist.github.com/amacgregor/8275062.js"></script>

<script src="https://gist.github.com/amacgregor/8275757.js"></script>

## Constructor Injection

By using dependency injection we have more maintainable code, in the previous example we are using a type of dependency injection normally referred as **Constructor Injection.** By doing a simple change we can reduce the level of complexity of our code and improve the overall quality; not to mention that now we can easily run unit tests.

Constructor injection is by far the most common method used and there are several advantages by using this particular type of injection:

- If the **dependency is required** by the class and cannot work without it, by using constructor injection we guarantee that the required dependencies are present.

- Since the constructor is only ever called when instantiating our object we can be sure that the **dependency can't be changed or altered during the object lifetime.**

These two points make Constructor Injection extremely useful, however there is also a few drawbacks that make it unsuitable for all scenarios:

- Since **all dependencies are required**, it's not suitable when optional dependencies are needed.

- While using class inheritance trying to extend and **override the constructor becomes difficult.**

## Setter Injection

Another common type of dependency injection is called setter injection and the same code as above would look something like this:

<script src="https://gist.github.com/amacgregor/8275062.js"></script>

<script src="https://gist.github.com/amacgregor/8275875.js"></script>

As we can see, with Setter Injection the dependencies are provided to our class after it has been instantiated using setter methods. Setter Injection has a few advantages:

- Allows for **optional dependencies** and the class can be created with default values.

- **Adding new dependencies is as easy** as adding a new setter method and it won't break any existing code.

**Setter Injection** might be more suitable for situations where more flexibility is required.

## So is Dependency Injection right for my application?

At the end of the day is up to each developer the one that has to make the decision about what design patterns are the right fit for his application be it **Dependency Injection** or something else; that being said from personal experience using patterns like this might be an overkill for smaller projects.

But if you are working on large and long running project, then there is good chance that dependency injection might the right solution for your project.

#### If you have any stories about using Dependency Injection in the real world and you would like to share please leave a comment down below.
