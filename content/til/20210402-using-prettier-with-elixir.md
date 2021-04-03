%{
title: "Using Prettier With Elixir",
category: "Programming",
tags: ["programming","elixir","functional programming","phoenix"],
description: "How to leverage and set up prettier js for working with html eex templates",
published: true
}
---

<!--How to leverage and set up Prettier.js for working with .html.eex templates-->

A while back elixir added `mix format` as a way to provide an opinionated and standard set of formatting for `ex` and `exs` files. 

There is however a gap when it comes to Phoenix `eex` and `leex` templates. Fortunately we can leverage [prettier.js](https://prettier.io/) as a format solution to cover this gap.

**1. Install the prettier main library and plugin**

```bash 
$ cd assets/
$ yarn add -D prettier prettier-plugin-eex
```

**2. Add some basic configuration**

file: `.prettierrc.js`

```javascript
module.exports = {
  printWidth: 120,
  eexMultilineLineLength: 100,
  eexMultilineNoParens: ["link", "form_for"],
};
```

file: `.prettierignore`

```
deps/
_build/
.elixir_ls
assets
priv
```

**3. Add a couple `mix aliases`**

```elixir
  defp aliases do
    [
    ...
      prettier: "cmd ./assets/node_modules/.bin/prettier --color --check .",
      "prettier.fix": "cmd ./assets/node_modules/.bin/prettier --color -w ."
    ]
  end
```

### References 

- [Prettier eex plugin discussion](https://elixirforum.com/t/prettier-eex-plugin/37067/5)
- [Prettier EEX Plugin](https://github.com/adamzapasnik/prettier-plugin-eex)