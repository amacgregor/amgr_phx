%{
title: "Swiss Army Knife Syndrome",
category: 'Programming',
tags: ['software design','software architecture', 'programming'],
description: "A tool with so many features and implements that ends up being completely useless, in my experience the same problem can apply to software; more often than not as developers we will try to include a feature or a piece of code"
}
---

<!--
  We need more chef knives and less swiss army knifes
  Good software is like a chef's knife sharp and with purpose
-->

I apologize beforehand if this article is more of a **rant** than usual. The inspiration for the **"Swiss Army Knife Syndrome"** came from my frustration in dealing with project managers, clients, and even other developers, that think in too much of a narrow, particular way. I call it the "Swiss Army Knife Syndrome".

## The Swiss Army Knife

<p style="text-align:center"><img style="display:inline-block" src="https://digital.hammacher.com/Items/74670/74670_1000x1000.jpg" width="500" alt="Largest swiss army knife in the world"/></p>

The term 'Swiss Army Knife' is often used to describe a collection of useful items or tools that are able to perform well in multiple scenarios.

While this may be useful, there are **risks to be aware** of as well. A tool with too many moving parts can end up being completely useless! By trying to do everything, said tool might be great at nothing.

In my experience, the same problem can apply to software. More often than not, developers try to include a feature or piece of code just **because it is "cool"**; project managers will try to modify the scope in the middle of a project because "X" or "Y" feature will add more value; customers will request extra features or functionality because they read or heard they were "critical" to their business.

This 'Swiss Army Knife Syndrome' can take many shapes: **scope creep, early optimization, and so on**. But the root of the problem is how we perceive and value software, work, and the value attached to it:

<div style="font-size:60px; text-align:center">More Features<br/>=<br/> More Value</div>

In reality, and for most cases, **the opposite is true**. The more complex a piece of code or software gets, the less value it provides. A personal example that illustrates this concept was a simple, pivotal dashboard for Demac Media internal use.

The original application was simple: we needed a way of (1) seeing all the tasks assigned to a particular team and (2) to filter them by the current week or two week sprint-basically, a task aggregator with basic filtering.

I coded the simple concept over the course of one weekend. Upon showing this to my team's project manager the following Monday, he deemed the application useful.

<div style="font-size:50px; text-align:left">
 ... but it would be so much better if ...
</div>

And that's how **Swiss Army Knife Syndrome** begins: with a 'but'. The tool was shared with other teams. Before they even started using it, we had a list of half a dozen features that were 'needed' or would add more value to the application. Suddenly, we had a number of requests well beyond the initial scope of the application.

## Clear Purpose

<p style="text-align:center"><img style="display:inline-block" src="https://www.euro-knife.com/sub/euro-noze.sk/images/shop-active-images/kuchynske-noze-victorinox-kucharsky-noz-7.7403.20..jpg" width="750" alt="Largest swiss army knife in the world"/></p>

{% excerpt %}
**Software needs to be as clean and as simple as it can practically be.** To follow the knife analogy, good code should be like a chef's knife. A chef's knife has a clear and defined set of uses. A professional chef will use the right kind of knife for the job. This is how we should think about our code.
{% endexcerpt %}

<div style="font-size:60px; text-align:center">
Do one job and do it well.
</div>

We find the same principle in software design, often referred as the Single Responsibility principle:

> ...The single responsibility principle states that every class should have a single responsibility, and that responsibility should be entirely encapsulated by the class. All its services should be narrowly aligned with that responsibility.

## Conclusion

No company, project manager, developer, or client is exempt from falling for this faulty logic. We are inclined to think that having and doing more is equivalent to being better or having more value. **Software should be elegant, and elegant code is where simplicity meets a good solution.** Therefore, it is our responsibility as developers to ensure that every bit of code we produce is as elegant and succinct as possible.

**Special Thanks to:**

Mark Holmes - [markholmes.io](https://markholmes.io/)
