%{
    title: "Using Abbreviations instead of Aliases",
    category: "Linux",
    tags: ["linux", "tips", "shell", "fish"],
    description: "Why you should start using abbreviations instead of aliases"
}
---

<!--A great alternative to aliases-->

I recently came across one of [Fish shell](https://github.com/fish-shell/fish-shell) best and likely most underrated features, **abbreviations**; a great alternative to **aliases** and dare I say a full replacement.

## The Problem with Aliases

> An alias is a (usually short) name that the shell translates into another (usually longer) name or command. Aliases allow you to define new commands by substituting a string for the first token of a simple command.

The main issue is that aliases are expanded behind the scenes, take the following alias:

```bash
alias rm='rm -Rfi'
```

The way aliases work on most shells the following drawbacks become apparent:

- They hide what is really happening as they are resolved behind the scenes
- Makes copy-pasting a command-line for instructions to others, difficult of not impossible
- Command history will be recorded as the alias, so history loses value
- Aliases become less valuable if you have to edit the options

## The better approach

**Abbreviations** work on the same principle as **aliases** but with the main advantage that an abbreviation will get expanded 'live' as is being typed. Let's look at the following example:

```bash
abbr --add miex "iex --erl "-kernel shell_history enabled" -S mix"
```

I converted this from an alias that I used on a daily basis for elixir development, here are the advantages so far:

- The `abbr` expands "live", the git completions work as normal and commandline doesn't have to lie or do any other hacks like that.
- Clean history. Using abbr means other developers can understand your terminal history.
- Easy to use a shortcut that’s close to what you want and edit it.

## Summary

- `abbr` make for a better and more understandable `alias`
- I'm replacing all my aliases with abbreviations

### Further Reading

- [Managing abbreviations - Fish](https://fishshell.com/docs/current/cmds/abbr.html)
- [When an alias should actually be an abbr](https://www.sean.sh/log/when-an-alias-should-actually-be-an-abbr/)
