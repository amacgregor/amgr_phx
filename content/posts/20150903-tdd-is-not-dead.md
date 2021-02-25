%{
title: "TDD is not Dead",
category: 'Testing',
tags: ['testing','programming','TDD','BDD'],
description: "TDD is not dead, not really. And it won't really ever be dead, it will change or be replaced with something better; in fact it already has, and in my MagentoTDD book we focus on Behavior Driven Development, an approach that emerged from the original TDD methodology."
}
---

So, where does this whole **TDD is DEAD** thing came from? Well, it all started with let's say a provocative talk and follow up blog post by David Heinemeier Hansson (@DHH) where he expressed his frustration with testing and put into question the value of TDD.

To break down DHH's points and concerns against TDD:

- Developers make you feel like your code is dirty if you don't practice TDD.
- Driving design from unit tests is not a good idea.
- TDD notion of "fast tests" is shortsighted.
- 100% coverage is silly.
- TDD created test-induced design damage.

TDD is not dead, not really. And it won't really ever be dead, it will change or be replaced with something better; in fact it already has, and in my [Magento Extension Test Driven Development](https://magetdd.com) book we focus on Behavior Driven Development, an approach that emerged from the original TDD methodology.

> Behavior-driven development combines the general techniques and principles of TDD with ideas from domain-driven design and object-oriented analysis and design to provide software development and management teams with shared tools and a shared process to collaborate on software development. -- **[Wikipedia](https://en.wikipedia.org/wiki/Behavior-driven_development)**

I'll quickly address each of DHH's points:

#### 1.- Developers make you feel like your is dirty if you don't practice TDD

I agree, this sucks! **Developer shaming is never a good thing.** Rather than shaming a developer that doesn't do TDD or testing; teach and share. That's the best way to help the community grow.

#### 2.- Driving design from unit tests is not a good idea

I don't agree. Tools like **PHPSpec** do an incredible job helping us not only to test our code, but to drive our design and produce cleaner code.

#### 3.- TDD notion of "fast tests" is shortsighted

Well, not true at all. When working on a TDD cycle, you want your test to **run as fast as possible** (within reason) to get that constant feedback and validate your code.

#### 4.- 100% coverage is silly.

I have to agree on this one. Be pragmatic about your testing. Test only when it matters and think twice to see if your test is adding value.

#### 5.- TDD created test-induced design damage.

Again, I have to disagree. Properly used **TDD/BDD** can lead to clean, maintainable, and easy to understand designs. Blaming TDD for poor design is like blaming your IDE for poor code indentation; be pragmatic with your tools.

### Testing sounds like too much work / Testing will make my development slower

TDD does add a bit more overhead, specially while you are still getting familiar with the tools and the process. So I won't lie to you, chances are that your process will get slower in the beginning, but as you get better with the tools and more accustomed to the testing process, you'll become faster.

<div style="font-size:50px; text-align:left">
Think about writing tests as an investment account; you will see a greater return of your investment with time.
</div>

Also with **Phpspec**, our tests are thorough code examples and a form of living documentation. But how does all that apply to Magento?

### Magento 1.x is not testable, it is impossible to write tests for it.

Testing Magento 1.x has always been a difficult topic; Magento (at least in its current iteration) doesn't lend itself too well to testing.

Over the years, there have been several attempts at providing some degree of testing to the platform: from the official **MTAF** (Magento Testing Automation Framework) to the community-driven tools like **Ecomdev's PHPUnit** extension.

For the longest time, testing was something that wasn't discussed that much in the Magento community, and honestly it is not surprising, since building proper tests for Magento extensions can be difficult even for seasoned veterans; let's not say the junior developer just getting started with Magento.

### Magento 2 and the Grail of Testing

**Magento 2** is changing that for the better by using design patterns like dependency injection and by having a massive test suite from the start. As with any change, you can see some resistance and skepticism among the community members. To be honest, it's not without reason, I for one find the concept of **100% code coverage misleading**. After all, useless tests do exist. With all that being said, I'm hopeful of the changes that Magento2 is introducing both to codebase and the developer community. I truly believe that for the most part they are positive ones.

At the end of the day, it is the community's opinion what matters, so what do you think? Is Magento2 overusing dependency injection? Is the test suite useful? How will the introduction of all these new paradigms change the way you develop Magento extensions? Don't hesitate to leave a comment below.

P.D: Parts of this post were taken from my new book [Magento Test Driven Extension Development](https://magetdd.com) if you are interested to learn more about TDD/BDD development in Magento go ahead and click the link!
