%{
title: "Hello Hack", 
category: 'Programming',
tags: ['php','hhvm','hack'],
description: "Recently Facebook unveiled Hack, a new programming language that aims to provide developers with the tools to write and ship code quickly while catching errors on the fly."
}
---

Recently Facebook unveiled **Hack**, a new programming language that aims to provide developers with the tools to write and ship code quickly while catching errors on the fly.

## What is Hack?

**Hack** is as programming language designed to work with HHVM and the same time it works seamlessly with **PHP** as Facebook lead devs:

> Hack has deep roots in PHP. In fact, most PHP files are already valid Hack files. [Facebook](https://code.facebook.com/posts/264544830379293/hack-a-new-programming-language-for-hhvm/)

So does that mean that **Hack** is just a faster more efficient PHP implementation, right? Wrong, **Hack** is much more than that, the language brings features that are normally found in statically typed languages to the dynamically typed world of \*PHP\*\*.

> Hack reconciles the fast development cycle of PHP with the discipline provided by static typing, while adding many features commonly found in other modern programming languages... [Facebook](https://code.facebook.com/posts/264544830379293/hack-a-new-proogramming-language-for-hhvm/)

### Static typing

In a **dynamically typed** language like php variables types and its values are both mutable, this means that a variable can start like a null then take a string value and finally change to an integer all inside the same _local scope_. While this is great for writing scripts and simple applications; as things start to scale the codebase will become harder and harder to maintain.

With millions of lines of codes and hundreds of developers working on the same code base on daily basis this is exactly what happened at facebook, which was originally developed in **PHP** and now is running almost entirely on **Hack**.

The main and so far most noted feature in **Hack** its is static typing. In Hack you can annotate variable, function return types and, the function member variables. This alone can help tremendously to prevent errors like the following:

`gist:amacgregor/9717629`

On the snippet above **dbfetch()** could return a null value instead of the object that our code is expecting; PHP errors can only be caught at runtime, but with Hack we can run a type checker against the code and catch this type of errors early in the development cycle.

### More than static types

There is more to **Hack** than static types among the many features the language implements we have:

- Collections
- Tuples
- Traits
- Lambda Expressions
- Generics
- Async Programming

And that's only a few of the features that the language has to offer, Collections are particularly interesting since the come as replacement for **PHP Arrays**, Traits and Trait Generics are a welcome addition, Async programming gives developers the option to develop non-blocking code.

## Summary

There is a lot that **Hack** has to offer to the PHP community, personally I think **Hack** is a welcome addition to the PHP Universe. Although the general reaction has been mostly positive there has been some criticism and negativity towards **Hack**, and Facebook decision to stick with PHP.

And while **Hack** stability and adoption has yet to be put to the test, the mere fact that something like **Hack** exists is beneficial for the community and PHP as a language, there is a very good chance that many of the feature hack has could be ported to future PHP versions.

Finally, there is one massive strength that in my opinion **HHVM** and **Hack** currently have on their favor and that is the seamless interoperability between **Hack** and **PHP**; developers can take a large codebase and slowly start rewriting the code in **Hack** class by class even as far as individual functions while the rest of the application is still running on PHP.

I was able to put this to the test by _hackifying_ a small **Magento** extension and have it run successfully along with Magento.
