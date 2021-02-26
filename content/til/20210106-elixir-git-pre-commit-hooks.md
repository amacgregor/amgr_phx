%{
title: "Elixir Git pre-commit hooks",
category: "Programming",
tags: ['git','elixir','programming'],
description: "Better tooling and development flow for elixir development"
}
---

<!--Better tooling and development flow for elixir development-->

Part of my Elixir development flow is to run certain checks and test before pushing changes to the remote. The main thing that I want is to make sure my code is following the standard Elixir formating with `mix format`.

We can easily do this with a `pre-commit` hook:

```bash
#!/bin/bash
cd `git rev-parse --show-toplevel`
mix format --check-formatted
if [ $? == 1 ]; then
   echo "commit failed due to format issues..."
   exit 1
fi
```
