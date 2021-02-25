%{
title: "Exploring Traits",
category: 'Programming',
tags: ['programming','traits','best practices'],
description: "Traits are a mechanism for code reuse in single inheritance languages such as PHP. A Trait is intended to reduce some limitations of single inheritance by enabling a developer to reuse sets of methods freely in several independent classes living in different class hierarchies. The semantics of the combination of Traits and classes is defined in a way which reduces complexity, and avoids the typical problems associated with multiple inheritance and Mixins."
}
---

Among the new features and fixes that come with **PHP5.4** we have the addition of traits to the PHP language, PHP is a single inheritance language this means that classes and only inheriting from single parent class, in practice this complicates code organization and can lead to code duplicity.

Languages like **C++** or **Python** manage this problem by allowing inheritance from multiple classes, Ruby in the other hand uses **Mixins** to address this issue. Regardless of the technique the problem remains the same; Traits are another approach to this problem and are commonly used in the languages like **Perl** and **Scala**.

Although PHP5.4(and Traits) has been around since early 2012, a lot of php developers might not be familiar with the concept and power behind Traits; In this article I want to explore traits, their usage, advantages and disadvantages.

## PHP and Multiple Inheritance

The main reason behind PHP lacking **multiple inheritance** is the lack of concensus of how to solve the **diamond problem** which arrises when multiple inheritance is implemented. The diamond problem can be described as an ambiguity in multiple inheritance OOP; but let's see an example to understand what th is means.

The **diamond problem** gets its name from the shape that the class inheritance takes in the particular situation where:

> ... two classes B and C inherit from A, and class D inherits from both B and C. If there is a method in A that B and/or C has overridden, and D does not override it, then which version of the method does D inherit: that of B, or that of C? [wikipedia](https://en.wikipedia.org/wiki/Multiple_inheritance#The_diamond_problem)

So assuming **PHP** would allow for multiple class inheritance(which it doesn't) the diamond problem would look something like this:

`gist:amacgregor/9456741`

Whoops at that point (if PHP actually had multiple inheritance) we would get an error saying, since **PHP** wouldn't know which **roar()** implementation to call.

This in essence is the problem with multiple inheritance, (un)fortunately PHP being a single inheritance language doesn't have this problem and with the PHP5.4 we can implement similar functionality to multiple inheritance model.

## A Trait Traits

> Traits are a mechanism for code reuse in single inheritance languages such as PHP. A Trait is intended to reduce some limitations of single inheritance by enabling a developer to reuse sets of methods freely in several independent classes living in different class hierarchies [php.net](php.net/traits)

An easy way to conceptualize **traits** would be to think of them as an interface with an implementation. As we mentioned before single inheritance has been part of **PHP OOP** (Object Oriented Implementation) over the years this more than one developer has been frustrated by this characteristic when trying to write code that is both clean on a complex system.

With Traits we can reuse functionality from other classes without having to extend them. Now, this might sound like multiple inheritance but the traits implementation is more akin to **horizontal code reuse**; Inheratence in the other hand is considered **vertical code reuse**.

As we mentioned before Traits are similar to Abstract classes, for example they cannot be instantiated on its own. Let's look at the following example:

`gist:amacgregor/9573105`

Now, if you are thinking that could you have done the same by creatin a **Cat** class that extends the **Animal** class and extending our **Tiger** class from there; take the following example into consideration:

`gist:9573275`

Wasn't that cool? Try to do that with single inheritance.

The best part about traits is that it makes sense from a structural point of view, think about it Cats and BigCats share many traits among them but not all of them, for example we could break it down even further:

`gist:9573439`

## Conclusion

Traits are an incredible addition to the **PHP** language and we have only started to touch the surface, in future articles will go over some of the more advance usages and caveats of using Traits.
