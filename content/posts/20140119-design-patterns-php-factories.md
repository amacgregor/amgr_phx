%{
title: "Design Patterns in PHP: Using Factories",
category: 'Programming',
tags: ['php','design patterns','programming'],
description: "The factory pattern is a class that has some methods that create objects for you. Instead of using new directly, you use the factory class to create objects. That way, if you want to change the types of objects created, you can change just the factory. All the code that uses the factory changes automatically."
}
---

The factory pattern is one of the most commonly used Design Patterns, it is useful when we need to choose between several interchangeable classes at runtime. By using factories we are also separating the creation of an object from the actual implementation.

We can define a factory as a simple design pattern that give us a convenient way to instantiate objects. A factory is capable of creating different types of objects without necessarily knowing what type of object is actually being created.

**Factories** try to address the problem of tight coupling in large application, with a factory instead of calling new directly, we use our factory class to take care of creating of the object.

There are **several implementations** and variants of design pattern among of which we have:

- Simple Factory
- Abstract Factory
- Factory Method

On this post we are going to focus on the **Factory method**, which is closer to the original Gang of four definitions and has more practical applications, as a side note the **Simple Factory** is normally not considered an actual pattern by many developers.

Personally I do consider the **Simple Factory** to be a pattern, just a rather simple one; and I'm not going to start a debate about what pattern is or is not.

As you can probably gather from the pattern name, a **Factory Method** works by using a class method for creating and instantiating the required objects.

## When to use a Factory

Know we have a general idea of what a factory class is and what is used for, but when is it appropriate to use it? Factory classes are generally used when:

- A class cannot anticipate the object types that needs to create beforehand.
- We want to encapsulate the logic for instantiating complex objects.
- We want to reduce tight coupling between our application classes.

Enough talking let's create some practical examples of factory class usages.

## Show Me The Code!

Let's imagine that is our first day at the **Ikea Product Factory** and we have been tasked with maintaining and updating the code; as you can imagine, this being Ikea, there are thousands of different products and products types. For the sake of argument, let's imagine that every single product has its own unique class. So we would have something like this:

<script src="https://gist.github.com/amacgregor/8506593.js"></script>

So as in the code example above, we have a **Product** abstract class that implements the construct function and the getters and setters that are shared among all the product classes. For each product we have a class inheriting from the **Product abstract class.**

You also notice when reading the existing code is that there are hundreds of calls to instantiate each individual product class. Like so:

<script src="https://gist.github.com/amacgregor/8506877.js"></script>

A clearer example of how this can become problematic is if we had a controller running on **https://factory.ikea.com/product/create/{product_type}**, this controller is in charge of instantiating a new product objects based on the $product_type provided, validating and adding the information posted and saving the product.

We are going to ignore the logic for validating the data and saving the product, right now we only care about how that product object is being instantiated without the use of a factory:

<script src="https://gist.github.com/amacgregor/8507273/ce8353737d091d4a25fd807ce5ca699bb264ae97.js"></script>

What's the biggest problem with this code? Simply put since our controller doesn't know beforehand what type of product it's going to create, our fictional **Ikea developers** used a switch statement to handle the right class instantiation.

Now you might be thinking that doesn't look so bad? It gets the job done, right? Well remember that it is our fictional **IkeaFactory** and we have hundreds of different product classes; meaning that if this was a fully implement class we would have hundreds of different cases on our switch statement.

The previous example is not only messy but hard to maintain too, what would a happen if we suddenly added a new parameter to our **\_\_construct()** function? You guessed right; that would mean updating every single instance where we call new on any of the product classes; that would mean a few hundred lines changed on our example controller function.

Let's see how implementing a basic factory can help us write better and more maintainable code. First we need to create a new class called **ProductFactory**

<script src="https://gist.github.com/amacgregor/8507938.js"></script>

And now lets refactor our controller action to use our new factory:

<script src="https://gist.github.com/amacgregor/8507273/a1d7341078c7692ad71d7609ece52eaee81faa0e.js"></script>

Lets that sink in for a second, we just replaced hundreds of lines of code with a single line and a new class. Now if we had the same scenario where we had to change our constructor function we would only had to change a few lines in our factory method.

## Summary

In this post we went over the advantages of using the Factory Method patterns to simplify or code, and make it more manageable. Although the examples in this post where simple ones, the purpose was to exemplify the basic concept rather than a full explanation of every single usage scenario and advanced usages.

Please feel free to leave a comment with ideas, corrections or your opinion on the topic.
