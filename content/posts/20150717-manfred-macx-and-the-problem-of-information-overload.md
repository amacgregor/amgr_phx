%{
title: "Manfred Macx and the Problem of Information Overload",
category: 'Technology',
tags: ['futurology','technology','information overload'],
description: "I have always been fascinated with the technology concepts presented on Charles Stross book Accelerando, artificial cats, downloads of consciousness, nanotechnology, etc. but of all of them one got my particular attention; Manfred Marcx glasses."
}
---

I've always been fascinated with the technology concepts presented on **Charles Stross** book _Accelerando_, artificial cats, downloads of consciousness, nanotechnology, etc. but of all of them one got my particular attention; Manfred Marcx glasses.

Glasses? What's so special about the glasses? Well this are not an ordinary pair of glasses, they are in fact augmented reality glasses, informing Manfred about recent news, results from search agents, phone calls, navigation instructions and what ever information he desires.

We could call them **smart glasses**, in the book this glasses allow Manfred to be on the bleeding age of technology and information; to the extreme without them he is incapable of functioning.

> In Charles Stross’ Accelerando, the arrival of the technological singularity is prefaced in the first section of the novel with the story of Manfred Macx, a hyper-connected, post-economic entrepreneur who relies on reputation and good-will rather than traditional monetary wealth.
> -- **Source: [Post-human, post-memory: Mnemotechnology in Charles Stross' Accelerando](https://www.academia.edu/1247436/Post-human_post-memory_Mnemotechnology_in_Charles_Stross_Accelerando)**

The attractive part here is not the augment reality glasses themselves but system that powers them, an exocortex.

> An EXOcortex can best be described as the portion of a trans- or posthuman entity's brain (or cortex) which exists outside of that entity's primary computing structure, usually the brain inhabiting a person's "meatbody." For example, a person's exocortex could very well be composed of all the external memory modules, processor, and devices that the person's biological brain interacts with on a realtime basis, thereby in effect making those external devices a functional part of the individual's "mind." -- **Source: [Wikibooks](https://en.wikibooks.org/wiki/Accelerando_Technical_Companion)**

While we are still years if not decades away of being able to directly enhance our biological brain with help of external hardware, current technology should be more than sufficient for creating at least an early version of the software an exocortex system would need.

## Defining the implementation

The first instinct for a project like this would be to go and develop a complex architecture, maybe a multi-agent system; yes that would be cool .... and also extremely complicated. But, what if switch the concept a little bit, what if instead of having a swarm of intelligent agents, we use a micro-service architecture.

**Could that work?** Will that architecture work or fail miserably due to:

- network latency
- message formats
- fault tolerance
- deployment complexity

_**NOTE:** The system should not only help with data consumption and processing but also with information generation._

> If we’re not doing something with the information we’re taking in, then we’re just pigs at the media trough.

Here is where the challenge comes in, I can build a system that feeds me information, sure. But can I build a system that, helps me to generate content faster and more efficiently.

> The metacortex is the Web — our growing global network of information, people, sensors, and computing devices.

Also would that be considered an exocortex or more akin to a metacortex, all relevant questions but besides the point of an initial prototype implementation.

More interesting are the advantages of a distributed system like this, and the mailability it could offer. A system that is comprised of microservices wouldn't care about the implementation of each service; as long as they respect the common contract for communication.

> The Web is literally a new layer of the human brain that transcends any individual brain. It is a global brain that connects all our brains together. It is intelligent. It is perhaps humanity’s greatest invention. It collectively senses, reacts, interprets, learns, thinks, and acts in ways that we as individuals can barely comprehend or predict, and this activity comprises an emerging global mind. -- **Source: [Nova Spivak](https://www.novaspivack.com/web-3-0/a-new-layer-of-the-brain-is-evolving-the-metacortex)**

Although even in a distributed service architecture there has to be a central point of orchestration, a system or process that is in charge of defining and running the tasks.

# Option 1

- Create a chain of events and services
- Each service in the chain calls back to the next service in line
- The task runner is only concerned about starting the chain of events

# Option 2

- Decoupled services
- Central system implements adapter for each
- Runs each step of the task passing the relevant data
- Can track the progress of each task.

At this point in time Option 2 seems more attractive, it also gives me the flexibility to integrate third party services into this structure without having to code the service myself. And I can leverage sites like [mashape.com](https://www.mashape.com) to help me with at least the initial implementation.

> An exocortex is a theoretical artificial external information processing system that would augment a brain’s biological high-level cognitive processes.
> An individual’s exocortex would be composed of external memory modules, processors, IO devices and software systems that would interact with, and augment, a person’s biological brain. Typically this interaction is described as being conducted through a direct brain-computer interface, making these extensions functionally part of the individual’s mind. -- **Source: [Wikipedia](https://en.wikipedia.org/wiki/Exocortex)**

## Narrowing the Scope

To measure progress and success, I need to define achievable goals first, in order to do that I have to narrow the scope and define what I want to gain from my "exocortex".

**_Do I want ..._**

- Better **memory** and indexation
- Help with **data** consumption
- Improve my content **output**
- **Automated** tedious tasks

Well, yes to all the above; but which one(s) would help me the most right now? Based on my current goals, and the current challenges I'm facing; data consumption and subsequently content output would be extremely handy.

Still, the scope seems to wide; we can narrow it further if we set an example use case.

### Example 1

```
EVERY [30min]
	GET [rss_feeds] OF [www.joelonsoftware.com,blog.cleancoder.com]
		AND GET [subreddit] OF [programming,coding,php]
		AND GET [hnews]
THEN
	DO [categorization] of {title}
WHEN
  {categories} HAVE_ONE_OF [tdd,bdd,agile]
  POST_TO [Summarizer Queue]
```

### Example 2

```
EVERY [30 minutes]
	GET [RSS feeds] OF [www.joelonsoftware.com, blog.cleancoder.com]
		AND GET [Subreddit feeds] OF [programming, coding, php]
		AND GET [HNews New]
	THEN
		DO [Categorization] OF {title}
		DO [Classification] OF {title}
WHEN
	{score} GREATER THAN > [0.7]
	POST TO [Direct Email]
WHEN
  {categories} HAVE ONE OF [tdd,bdd,agile]
  POST TO [Summarizer Queue]
```

## What's next?

Sounds good so far, I been working on the architecture for this project for the last year or so, and already have a working prototype for data collection. Here is where the fun part begins since I can collect reasonable amounts of data what should I do with them?

I'll go over the details of the data collection implementation on the next post.
