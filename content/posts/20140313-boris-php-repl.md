%{
title: "Boris The Missing PHP REPL",
category: 'Programming',
tags: ['php','programming'],
description: "REPL(read-eval-print loop) can be great tools for quickly testing concepts, experimenting and getting quick feedback when learning a new language. Many languages and frameworks provide some sort of REPL like the rails console or laravel's artisan tinker."
}
---

REPL(read-eval-print loop) can be great tools for quickly testing concepts, experimenting and getting quick feedback when learning a new language. Many languages and frameworks provide some sort of REPL like the rails console or laravel's artisan tinker.

PHP by itself has the interactive shell that can be invoked with:

```
php -a
```

However the PHP Interactive Shell lacks several features that other modern languages have in their REPL's; like proper error handling, multi-line support and result output by default.

# Meet Boris

> Python has one. Ruby has one. Clojure has one. Now PHP has one too. Boris is PHP's missing REPL (read-eval-print loop), allowing developers to experiment with PHP code in the terminal in an interactive manner. If you make a mistake, it doesn't matter, Boris will report the error and stand to attention for further input.

[Boris](https://github.com/d11wtq/boris), was developed by [Chris Corbyn](https://github.com/d11wtq) a PHP developer that after making the transition to Ruby was disappointed by the lack of a true PHP REPL.

<p style="text-align:center;"><img src="https://github-camo.global.ssl.fastly.net/18c23fa613beeb044a7ba1ba58a5dfefe120ca6f/687474703a2f2f646c2e64726f70626f782e636f6d2f752f3530383630372f426f72697344656d6f2d76342e676966"/></p>

After playing around with Boris for while, I can honestly say that it has the right to call itself 'The Missing PHP REPL'; not only provides the basic features that you would expect from a standard REPL but also:

- Output customization.
- Configuration files.
- Start Hooks.
- Loading larger applications.

On top of that Boris can be easily installed or included in any project using composer.

All these features make Boris a powerful and flexible tool regardless if you are just using it to test quick snippets or as part of a large application.
