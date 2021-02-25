%{
title: "Git Tips and Tricks",
category: 'Programming',
tags: ['git','programming','tips'],
description: "Useful collection of git tips and tricks"
}
---

Recently I've been collecting a large collection of git shortcuts, tips and tricks. The following
commands have been tested on linux and some of them will required a recent version of git.

I expect that many of you will find them useful as much as I do. So let's get started with some
simple but helpful commands to search and review your git repository history.

## Show log for only a specific branch

The following command can be used if you are working on a project with a particular dirty history or
a log of branches

```
git log --first-parent {branch_name}
```

## Show the log as a single line

The following command will show the commit has and the first line of the commit comment.

```
git log --pretty=oneline --abbrev-commit
```

A more advanced and nicer version of the command above is:

```
git log --graph --pretty=oneline --abbrev-commit --date=relative
```

## Search for a string in all commits across the entire git history

This can be really useful when looking for a particular piece of code to see when it was
added/removed:

```
git log -S{text_to_search}
```

## Shows branches that are all merged in to your current branch

```
git branch --merged
```

And in the same way we can see all the branches that haven't yet been merged.

```
git branch --no-merged
```
