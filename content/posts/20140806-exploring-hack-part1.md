%{
title: "Exploring Hack: Building a MicroFramework",
category: 'Programming',
tags: ['HHVM','programming','hacklang'],
description: "So to get started I've decided to build a micro-framework using HACK and HHVM, building a simple microframework should be a challenging enough task to illustrate some of the more interesting features of the language and at the same time it has an achievable goal so we don't end on a never ending development cycle."
}
---

As a full-time **Magento Developer** I deal with a very specific kind of **PHP** every single day; this can at time get rather boring since rarely one can apply
new technologies or programming concepts. One of the new languages that keeps grabbing my attention is **HACK**, which is almost identical to **PHP** in
terms of syntax but at the same time implements some of the more attractive features from statically typed languages.

> **Hack** is a language for HHVM that interopates seamlessly with **PHP**. The barrier to entry for Hack is low. To get started, all that is needed is to
> generally understand the features that **Hack** provides and how to call the Hack type checker (hh_client invokes the type checker at the command line)

I have covered **Hack** previously on the following articles:

- [Hello Hack](https://www.coderoncode.com/2014/03/23/hello-hack.html)
- [Is HHVM/Hack the new face of PHP?](https://www.coderoncode.com/2014/04/08/hhvm-hack-new-php.html)

## Learn by Doing

I honestly believe the best way to learn something is to get your hands dirty and make mistakes; so instead of writing dozens of post on
the many new features of **Hack** and why they are awesome (in theory) let's build something useful.

So to get started I've decided to build a micro-framework using **HACK** and **HHVM**, building a simple microframework should be a challenging enough task
to illustrate some of the more interesting features of the language and at the same time it has an achievable goal so we don't end on a never ending
development cycle.

Let's call our new framework something clever:

## Meet Slash

Get it? **Hack**, Slash (it's a clever name, shut up). Before we start writing any code let's think a little about what kind of micro-framework we want
to build. There are many amazing **PHP** micro-frameworks out there, just to mention a few:

- [Slim](https://www.slimframework.com/)
- [Silex](https://silex.sensiolabs.org/)
- [Phalcon](https://phalconphp.com/)
- [BulletPHP](https://bulletphp.com/)
- [Recess](https://www.recessframework.org/)
- [Limonade](https://limonade-php.github.io/)

Outside of the **PHP** world, there is **Sinatra** which is Ruby based and excellent example of a powerful micro-framework. Curiously enough Sinatra seems to
be the source of inspiraton for many of these frameworks; so let's not break tradition and use Sinatra as our main source of inspiration.

That means that Slash main purpose will to create **RESTful applications**, and as such the main component for a framework like this will be its router.

In the next post of this series we will go through the creating of the routing and the general structure of new microframework.
