%{
title: "Technical Debt",
category: 'Programming',
tags: ['programming','best practices','technical debt'],
description: "Technical Debt, chances are that you as developer have heard that term at least once before; but ask yourself do you really understand technical debt and when is appropriate to use it."
}
---

Technical Debt, chances are that you as developer have heard that term at least once before; but ask yourself do you really understand technical debt and when is appropriate to use it.

The term "technical debt" was first coined by Ward Cunningham who compared technical complexity and debt in a 1992 experience report:

> Shipping first time code is like going into debt. A little debt speeds development so long as it is paid back promptly with a rewrite... The danger occurs when the debt is not repaid. Every minute spent on not-quite-right code counts as interest on that debt. Entire engineering organizations can be brought to a stand-still under the debt load of an unconsolidated implementation, object-oriented or otherwise. -- **Ward Cunningham (1992-03-26). "The WyCash Portfolio Management System". Retrieved 2008-09-26.**

Basically technical debt refers to the shortcuts or hacks that we do and that will have future repercussions on our application, technical debt can also be acquired by inaction, like not commenting code, not generating documentation, skipping testing, and so on.

So if you ever had to hack things to make it work or skip testing just to meet a deadline; then you incurred into technical debt without knowing. Technical debt is usually paid inform of time and money spend fixing problems that could've been easily avoided if proper practices would've been followed.

## Technical debt is bad ... right ?

So technical debt has to be bad since we are only generating problems for our future selfs correct? Well not exactly and this is a topic of much debate among developers, if properly managed technical debt can become and asset instead of problem.

And while the previous point is highly controversial, modern companies seem to be embracing technical debt as part of their "Standard" methodologies for development, specially does who follow Agile practices. So what does this mean, does it mean that technical debt is desirable even to some extend ?

Purposely incurring into technical debt implies sacrificing quality and injecting hacky code into our project, instinctively developers find the idea revolting (at least I do) however more often than not as developers we are forced to bend the rules.

If you've ever worked for an "Agile" development company or one that likes to work with extremely close deadlines; you know exactly what I mean with bend the rules.

And one can even incur into technical debt without being aware of it, so the truth is that no matter what you are likely to incur into some technical debt.

## Dealing with Technical Debt

<br/>
<br/>

<h2 class="red">First rule of Dealing with Technical Debt: <strong>Never Ignore Technical Debt</strong></h2>

The worst thing you can do with any kind of technical debt is ignored it, recognize that technical debt comes with the interest and sooner or later you will have to pay; even if you incurred into technical debt for good reasons is important that you get rid of it as soon as possible.

<h2 class="red">Second rule of Dealing with Technical Debt: <strong>Set a repayment plan</strong></h2>

As we mentioned before debt is something that we want to get rid of as soon as possible, the same applies for technical debt.

For Technical Debt we want to specify a deadline to completely repay our debt back, this way you set a deadline and only allow the technical debt go on for a predetermined amount of time.

If we don't pay attention, technical debt has the tendency to hang around, and the more time goes by the hard it becomes to remove a specific piece of technical debt.

<h2 class="red">Third rule of Dealing with Technical Debt: <strong>Set a debt ceiling</strong></h2>

If you are not paying attention debt will pile on without you even noticing, for that reason is recommended that you setup a debt ceiling, a maximum amount that you can 'borrow' from your projects quality.

Setting a limit on how much debt a project can have helps keeps under control and forces you to think twice if that particular hack/change/compromise is really needed.

## Conclusion

Sooner or later everyone is forced to acquire some level of technical debt, the previous rules will help you to it responsibly and you will better equipped to get rid of the technical debt faster.

That being said, while researching for this article I found that there was a fourth rule that was being overlooked and that it should be the golden rule when dealing with technical debt.

<h2 class="red">Golden rule of Dealing with Technical Debt: <strong>Avoid Technical Debt</strong> </h2>

This sounds kind of obvious but in practice is much harder than it sounds, and for most part is us, developers who are at fault. We need to be more vocal and push back to try to avoid Technical debt; when the Project Manager, Sales guy, client says "Just make it work", "Hack it together, I don't care " or any similar cringe worthy phrases we need to stop and make them understand the consequences on the short and long term for the project and the code.

In the end the best way to deal with Technical Debt is not to have any to begin with.
