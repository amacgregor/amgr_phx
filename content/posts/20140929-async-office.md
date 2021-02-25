%{
title: "The Async Software Development Manifesto Revised",
category: 'Programming', 
tags: ['Programming','Software Engineering'],
description: "The Async Software Development Manifesto has been making the rounds on sites like HackerNews and /r/programming; and while I dont agree entirely with all that is proposed, some of the points made by the author made so much sense that I felt motivated to break them down and make some contributions of my own."
}
---

The ['Async Software Development Manifesto'](https://asyncmanifesto.org/) has been making the rounds on sites like HackerNews and /r/programming; and while I don't agree entirely with all that is proposed, some of the points made by the author made so much sense that I felt motivated to break them down and make some contributions of my own.

## Async Software Development Manifesto

The manifesto appears to be inspired by the ['Agile Manifesto'](https://agilemanifesto.org/) and it advocates for a different approach and tools, in direct opposition with the Agile methodology. The following principles are emphasized:

- Use Modern tools
- Meetings only as a last resort
- Flexible work environments
- Document everything

Now, even as principles some of those are very generic and to be honest quite vague; so in order to understand what the author meant by each of those principles we need to break them down further:

### Use Modern tools

On this point the **Async Software Development Manifesto**, which from now I will refer as the **ASDM** (since I'm getting tired of typing the whole thing) advocates for the use of modern tools like Bitbucket, Github, or Gitlab. The reasoning behind this is that those tools posses the following qualities:

- Each deeply integrates version control with issue tracking.
- Each offers rich prioritizing and assignment features.
- Each wraps all that up into a slick user experience that anyone on the team can use, including nontechnical people.

The point that seems to be made is the importance of having tools that integrate with work-flow and reduce the friction for the developers and everyone involved. In that sense tools like Bitbucket or Github certainly are effective at integrating and issue tracking system, and a version control system all tied together by a common interface that technical and non-technical people can share.

However, the argument needs to be made against using a single tool like these; not every company follows the same work-flow and not all the clients are willing to learn how to use issue tracking systems like the ones mentioned before.

In some cases letting clients directly raise issues, without any kind of filter can be contra-productive and generate unnecessary work for everyone involved.

The second point that I want to make is the use of the word modern, old or new, trendy or not; those should not be a factor when selecting tools and methodologies to use for your team and work-flow.

Modern also implies that any tools that have been lying around for a few years are obsolete and to be avoided, but that is hardly the case some popular tools like VIM have been around for a few decades and it's not showing signs of going away any time soon.

So in this case, I think the principle should be revised to:

<div style="font-size:60px; text-align:center">Use tools that work for you</div>

### Meetings only as a last resort

According to the ASDM **"meetings are very costly to your business"** due the time that they take away from developers and the cost of constant interruptions, several articles like [programmer interrupted](https://blog.ninlabs.com/2013/01/programmer-interrupted/), [why you shouldn't interrupt developers](https://heeris.id.au/2013/this-is-why-you-shouldnt-interrupt-a-programmer) and [the high cost of interruptions](https://www.infoq.com/news/2013/01/Interruptions) deal with the same concept; there is a cost that hidden when interrupting developers; so I agree with this part of the principle.

However, meetings specially the quick kind like daily stand-ups still have place, meetings shouldn't be the last resort however meetings must be use smartly:

- Interruptions should be minimized.
- Meetings should be meaninful and to the point.
- People should be hold longer than needed.

For example at [Demac Media](https://www.demacmedia.com/) we apply this principle by doing morning stand-ups, but only on Mondays, Wednesdays and Fridays; meetings are also kept sort usually under 15min and developers are not hold longer as soon as they are done they can leave the meeting.

The main point is to provide a quick checkpoint for the team, make sure everyone is on track, and giving an opportunity for jr developers to raise any issues or problems they might be thus avoiding miscommunication. There is value to be found on effective meetings, when meetings have a clear purpose they can actually minimize and prevent problems.

There is however a valuable point to be made about constant interruptions and their attached cost, I have found that the following measures are effective to minimize interruptions while still following the concept of **Async Software Development**:

- Instead of walking over to another developer to ask a '5min' question, write an email. Writing an email forces you to think about the problem and what you have done to try solving it. This is basically 'Async Rubber Ducking' chances are that the asking developer already knows the answer to the problem, but is needs to change the way he is looking/thinking about the problem.
- Define core hours, during core hours you should avoid interruptions (meetings, walking over, etc) the core hours should be a large chunk of interrupted time during the day. Define core hours will help developers to have a guaranteed and predefined period of time, that they can use to get complicated tasks done.

So in this case, I think the principle should be revised to:

<div style="font-size:60px; text-align:center">Use meetings wisely</div>

### Flexible work environments

Here the original ASDM goes into a few points of what does it mean to have a flexible work environment:

- Adopt a hotelling policy at your office.
- Don't assign desks to anyone by default.
- Anyone who requests an assigned desk should get to choose whether it's a private office or in a communal space.

And while I wholeheartedly agree with all those points, I think we have to be careful of how much flexibility is allowed. Some developers will completely isolate themselves if allowed to; and writing code in isolation is never a good thing.

<div style="font-size:60px; text-align:center">Be flexible with your process</div>

Be mindful about any process or policy, if the process gets in the way of actually getting work done then the process needs to change.

### Document everything

The original manifesto doesn't go into much detail on this last point:

> The better documented your work-flow, the less your workers will need to interrupt each other to seek out tribal knowledge.

And I must say I don't disagree, having proper documentation is always positive, however is how you generate and maintain this documentation what can cause problems.

It all comes down to making the documentation process unobtrusive and frictionless, this will help the developers to feel more comfortable while writing documentation and it won't interrupt their work-flow, that been said there is no better documentation than well written code.
