%{
title: "5 Rules for Writing Great Commits",
category: "Programming",
tags: ["programming","git","best practices"],
description: "One of the most underestimated skills that a developer can have is the ability to make well documented, clean commits. Writing good commits can save everyone involved in project tremendous amounts of time, money and effort"
}
---

One of the most underestimated skills that a developer can have is the ability to make well documented, clean commits.
Writing good commits can save everyone involved in project tremendous amounts of time, money and effort.

Other developers can quickly see what changes you made and why, and is extremely useful when tracking down when bugs where introduced.

## A Skill that requires practice

Choose a project, preferably one that you have been working for some time and has had least a few dozens commit. Now take a look at your commits and try to back track your work.
Not pretty right? At least it wasn't for me; I had to take a hard look at my workflow and realize that I was approaching commit messages more than an annoyance that needed to be quickly bypassed instead using them as valuable tool for team and myself.

In order to help me make my commits consistent I setup the following 5 basic guidelines that my commit messages should try to implement:

### 1- Keep your commits clean

By clean we are referring at the actual files that are part of a commit; and only adding the files that really need to be part of the actual commit or even the repository.

I have see many times commits that include log files, tmp/x folders, IDE configuration files, media files. This is not only unnecessary but adds a lot of overhead and possibly increases the size of a repository.

### 2- Commit early, Commit often

Commit as soon as you have one change ready, thing of your commits as brief snapshots you can use to roll back. Or even better different save games that allow you to go back at specific spots and approach a problem different.

By committing often we are creating a development history that we can use as reference and in the worst case scenario to roll back in case of a problem.

### 3- One whole change per commit

While I was already doing this with my regular commits I found that many new developers where packing multiple changes into a single commit, and writing messages like:

> Fixes vulnerability #222
> Changes css class
> Rewrites controller

Having multiple changes all into a single commits makes a bug harder to track down and complicates the process of rolling back

### 4- Specify why was the change made

Let's take a quick look at the previous message not only are multiple changes applied inside the same commit but we don't have any of clue of what was the reason behind that change.

One new practice that applying is adding a small reason sentences with a description of why the change was implemented for example:

> Rewrites controller
> Reason: The controller need be changed to implement x and y feature

### 5- Specify what was changed

Ok so our original commit message looks better but something still missing from it, we are not specifying that we change exactly, saying:

> Rewrites controller

It's not very specific a much better commit message would be:

> Rewrites some/module/CheckoutController.php

This simple guidelines can save you of a lot of headaches down the road, and if another developer has to look back at the changes that where implemented on a project, he is able to quickly follow the history of the project.
