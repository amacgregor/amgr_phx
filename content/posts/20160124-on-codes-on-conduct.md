%{
title: 'On Codes on Conduct',
category: "Society",
tags: ["codes of conduct", "community", "social justice", "equality"],
description: "My opinions and ruminations on the whole debate about PHP's code of conduct"
}
---

Recently, there has been a lot of controversy and discussion surrounding the adoption of a code of conduct for the PHP project; there has been endless back and forth between proponents and opponents of the motion. I've debated if I should publish my opinions on the subject or simply remain quite and hope for the best; however as emails from the internals list continued to flood my inbox, I found it harder and harder to just sit idly silent.

The following article(s) are heavily opinionated and there is a very good chance that you will disagree with my position and my arguments, the topic by is very nature is extremely contentious and of a sensitive nature. However, they say that **disagreement fosters communication and the exchange of ideas**; and I'm hoping that is true in this case. With that said, let's jump into the topic at hand and start talking about code of conduct.

## Codes of Conduct

> A code of conduct is a set of rules outlining the social norms and rules and responsibilities of, or proper practices for, an individual, party or organization. Related concepts include ethical, honour, moral codes and religious laws. -- wikipedia

Albeit general the definition above does a good job of describing the main goal of a code of conduct. Simply speaking, codes of conduct **dictate the way individuals should act and communicate with each other** in what is deemed a relevant space for a project. Now, inherently there is nothing wrong with the concept of code of conduct as we all can agree that we should strive to provide a welcoming and respectful space.

Unfortunately, as most things in the real world **it is not as simple as it sounds** and we need to at least be aware of the consequences, side effects, and political baggage documents like a code of conduct can have.

Let's start by taking a closer look to the Code of Conduct original proposed for the PHP project:

<script src="https://gist.github.com/amacgregor/1fb019c5a275d0ae7e38.js"></script>

That document is called the [contributors covenant](https://contributor-covenant.org), a template for the code of conduct currently **in use by around 10,000 open source projects** — impressive number, specially considering some of them are quite large. Before I jump into some of my more controversial opinions about this document, let's analyze the language and the document itself solely based on its content.

Let's break it down paragraph by paragraph.

> As contributors and maintainers of this project, and in the interest of fostering an open and welcoming community, we pledge to respect all people who contribute through reporting issues, posting feature requests, updating documentation, submitting pull requests or patches, and other activities.

Ok so far so good, there is nothing wrong or arguable with the first paragraph; striving to make **our community more open and welcoming is something all of us can agree with.**

> We are committed to making participation in this project a harassment-free experience for everyone, regardless of level of experience, gender, gender identity and expression, sexual orientation, disability, personal appearance, body size, race, ethnicity, age, religion, or nationality.

Here the waters start to get a little bit muddy, while at first glance everything seems reasonable enough, by taking a look at the language we can see a couple of issues; those mainly being that the **list of harassment topics is not wide enough** as well as the fact that the paragraph **doesn't set the scope** on which the project maintainers are supposed to act on.

Think about for a second, under the current covenant any comment, retweet, blog post, etc., could be taken in consideration for a harassment or discrimination complain; even if it has nothing to do with the PHP project.

Let me present a better version of the second paragraph:

> We are committed to evaluating contributions **within project channels** (such as reporting issues, posting feature requests, updating documentation, submitting pull requests or patches, and other project activities) without regard to the contributor's **level of experience, gender, gender identity and expression, sexual orientation, disability, personal appearance, body size, race, ethnicity, age, religion, nationality, politics, or activity outside of project channels.**

On it we limit the scope to only the project channels — which should be clearly defined in a later section — as well it accounts for political opinions and views of the contributors and defends them from discrimination. Let's move on to the next paragraph:

> Examples of unacceptable behaviour by participants include:
>
>     - The use of sexualized language or imagery
>     - Personal attacks
>     - Trolling or insulting/derogatory comments
>     - Public or private harassment
>     - Publishing other's private information, such as physical or electronic addresses, without explicit permission
>     - Other unethical or unprofessional conduct

Another paragraph that at first glance is hard to disagree with, but reading carefully we need to define what is considered personal attacks, trolling or unprofessional conduct.

Again open and **vague language can lend itself to abuse**, specially on a document that calls for drastic punitive action like this one does.

> Project maintainers have the right and responsibility to remove, edit, or reject comments, commits, code, wiki edits, issues, and other contributions that are not aligned to this Code of Conduct, or to ban temporarily or permanently any contributor for other behaviours that they deem inappropriate, threatening, offensive, or harmful.

And now we get to the part that causes me the most concern, the paragraph above describe the list of sanctions and punitive action that must be taken for anyone that is found violating the CoC.

Regardless if is temporary or permanent the act of banning someone from the project **can have real world consequences and affect people's livelihood**. I'll clarify what I mean with real world consequences and why I believe that whole idea of punitive actions is highly misguided further down the article.

> By adopting this Code of Conduct, project maintainers commit themselves to fairly and consistently applying these principles to every aspect of managing this project. Project maintainers who do not follow or enforce the Code of Conduct may be permanently removed from the project team.

I kept re-reading this paragraph, and it keep bothering; as a project maintainer you are not only bound to make the project fair and welcoming but you are bound to follow the covenant to the letter or get permanently banned yourself.

Again, the emphasis is in the punitive action; follow our rules or else!

> This Code of Conduct applies both within project spaces and in public spaces when an individual is representing the project or its community.

Finally, a mention of scope and limits … but no wait that's it ? Correct, again **extremely open ended and vague language;** you could argue that you are always representing the language in public and private, there are no boundaries; not for your own point of views, nor for personal life.

Vagueness can lead to situations where people get easily banned for comments, views or postings that are completely unrelated to the actual project; **it doesn't matter if you say that your tweets are 'performance art';** if someone deems them offensive you run the risk of getting labeled and thrown away from the project.

This exposes another weakness or oversight in the contributors covenant code of conduct, **it doesn't account for intent**, nor it takes provisions to restrict who can and can't report issues. Brandon Savage brought this point masterfully on the PHP mailing list — you can read the [full email here](https://news.php.net/php.internals/90850)—.

I won't cover the full extend of the issue as presented by **Brandon**, but here are his proposed inclusions and corrections to the CoC:

- The Code of Conduct should specifically state that a person who is not a direct party to the alleged incident is not permitted to make a complaint.
- We should require that any person who is accused of violating the Code of Conduct clearly have intent to do so. This is a harder standard to prove, but one that should help us from having to deal with edge cases. A death threat is a clear-cut case of intent, for example.
- The Code of Conduct should be modified so that abiding or not abiding by it is demonstrable with evidence, taking "feelings" out of it entirely. For example, a person shouldn't be in violation of the code because someone "feels harassed/trolled/etc", it should be because they're ACTUALLY harassed/trolled/etc.
- The Code of Conduct should bar filing a claim of harassment if harassment from both parties towards one another can be demonstrated. This avoids a race to the courthouse by one side to punish the other in an argument.

All **worthy additions** to the code of conduct to prevent abuse and limit the number of edge cases and people affected by them.

## Punitive action and the real world

Many of the concerns that have been voiced regarding this CoC are related to the apparent focus on punitive action; this CoC is at its core a **laundry list of forbidden behaviour** that people are required to avoid and to ensure compliance the threat of the perma-ban hammer hangs over their heads.

Unfortunately, this will likely not end with just one person getting banned from the PHP project but it could **potentially end up having more serious repercussions**. So far we have discussed the CoC in the PHP context; but let's remember that the current CoC is based and following the Contributors Covenant, which has the issues I listed above.

Currently, over 10,000 projects follow this contributors covenant as it's currently provisioned and enforced, **the following scenario is not outside of the realm of possibility:**

Once a developer is deemed in violation of the Contributors Covenant what stops any of the other covenant projects from saying **'Well he/her was labelled as an harasser/bigot/sexist by X project why should we allow him to do the same thing here in project Y less ban him/her before they can cause any harm'.**

Now, before I get accused of **fabricating straw-man** arguments or exaggerating let me clarify there is no indication or record that the scenario has occurred nor that there are any plans to do something of that nature.

Recently, I listened to a prominent figure inside the **PHP community talk** about the subject, all I can say is it was disappointing to hear said person take such a dismissive attitude towards the concerns of people that oppose to the current CoC.

If we are truly talking about creating a welcoming and open community, then we need to listen and address the concerns of **detractors** as much as we do for the proponents of the CoC; after all, the goal is equality and fairness; **is it not?**

Even without accounting for this scenario, getting banned from contribution under the **accusation of misconduct** could cause problems in the real world and their work; you could get you banned from conferences, affect publishing deals, in short, it could royally mess up with your career.

## Next steps forward

As it stands, the current proposal for the Code of Conduct has hit an impasse; the more the discussion seems to go on, the more it seems that the proposal is attempting to **setup a mini-judicial system;** and speaking candidly, the **PHP community is not capable of pulling this off.**

There are so many variables and processes, not to mention, the **balances and checks** that there would need to be in place in order for this to be successful. For that reason, I would like to put forward my own version of a code of conduct that I feel would be a better fit for the PHP Community, if anything at all, take it as a source of ideas coming from a different perspective.

I call it [The Pragmatist Code of Conduct](https://github.com/amacgregor/Pragmatists-Code-of-Conduct/blob/master/Prag-Code-of-Conduct.md)
