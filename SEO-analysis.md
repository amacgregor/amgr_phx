Let me pull up your site and dig in.Here's the honest assessment. There's a lot wrong, and most of it is self-inflicted.

---

## Identity Crisis: What Is This Site Actually For?

This is the core problem everything else flows from. The site tagline is literally "A blog about development" — which could describe 10 million sites on the internet. The About page still says you work at Humi and are based in Toronto. The Services page sells technical writing. None of this reflects your current reality as CTO at LiORA, your Elixir/fintech expertise niche, or your cleantech work.

**You don't have an SEO problem. You have a positioning problem.** Until you answer "who is this site for and what do they get from it," optimizing keywords is rearranging deck chairs.

## Content Strategy: A Decade of Drift

Your blog spans 2013–2026 and covers PHP, HHVM/Hack, Magento, Docker, Ethereum, neural networks, Elixir, Backstage.io, quantified self, and management opinion pieces. From a search engine perspective, this dilution is brutal:

**Topic authority is fractured.** Google rewards topical depth. You have ~15 Elixir posts scattered across 12 years mixed with ~15 PHP/Magento posts that are completely irrelevant to your current brand. The site can't rank for "Elixir fintech" or "Elixir patterns" when half the content signal is about PHP singletons from 2014.

**Publishing cadence is erratic.** You went from Aug 2023 to Dec 2024 with nothing, then Dec 2024 to Feb 2026 with a few posts. Google's freshness signals reward consistency. Three posts in two months followed by 16 months of silence tells crawlers this isn't an active authority site.

**Your strongest content isn't on your site.** Your publications page links out to AppSignal, Fiberplane, Saucelabs, Codecov, etc. Those are decent backlinks, but you're essentially building domain authority for others. The Elixir DI articles on AppSignal should have companion pieces or expanded versions on allanmacgregor.com driving traffic back.

## Technical SEO Issues

**Meta descriptions appear to be auto-generated or missing.** The search snippets for your pages are pulling body text rather than crafted meta descriptions. Every post should have a unique, keyword-rich meta description under 160 characters.

**The site title structure is weak.** "Blog · Allan MacGregor" tells Google nothing. Compare to something like "Allan MacGregor | Elixir Engineering & Technical Leadership" — that's what should be in the `<title>` tag.

**Copyright footer says © 2024.** Small thing, but it signals neglect to both users and crawlers.

**No visible structured data.** I don't see evidence of JSON-LD for articles (author, datePublished, dateModified), which means you're missing out on rich snippet opportunities in search results.

**The /eve page** shows up in search results as "Blog · Allan MacGregor" with no description. If that's your EVE Online page, it's either leaking into your crawl budget or confusing your topical signals. Noindex it if it's not meant for search traffic.

## What's Actually Working (Barely)

Your Elixir fintech post ranks well because it occupies a genuine content gap — there isn't much written about Elixir specifically for fintech. The circuit breaker pattern post also has decent niche authority. These are the seeds of a real strategy, but they're buried under noise.

Your publications page showing external writing credits at recognized tech publications (AppSignal, etc.) is strong E-E-A-T signal. But it's underutilized.

## The Real Competitive Weakness

Your Twitter/X has 2,665 followers and **zero posts**. Your ThePragmaticCTO Substack is referenced in your X bio but doesn't appear to cross-link with allanmacgregor.com. You have content spread across at least four properties (personal site, Substack, Obsidian digital garden, external publications) with no coherent funnel between them.

**You're splitting your audience across too many venues and none of them benefit from the others.**

## What I'd Actually Do

**1. Pick a lane.** "Elixir for regulated industries" (fintech, cleantech, compliance) is your natural niche. It's differentiated, it maps to your actual experience, and it has low competition with genuine search demand. Kill or archive the PHP/Magento/Ethereum/HHVM content — either move it to an /archive path with noindex or remove it from the main feed entirely.

**2. Fix the About and Services pages today.** They're actively hurting you. Anyone who finds you via search and lands on "I work at Humi" and "technical writing services" bounces immediately. This should reflect CTO at LiORA, the Humi acquisition story, and your actual expertise stack.

**3. Consolidate.** Either ThePragmaticCTO feeds into allanmacgregor.com or vice versa. Two half-maintained properties are worse than one well-maintained one. The Obsidian digital garden is fine as a personal knowledge base, but it shouldn't be in your main nav competing for attention.

**4. Publish 2-4 Elixir/engineering leadership posts per month** targeting specific long-tail keywords: "elixir ecto n+1 queries," "elixir circuit breaker genstatem," "elixir fintech compliance," "phoenix liveview real-time dashboards." Your Feb 2026 posts are doing this — that cadence needs to be permanent.

**5. Every external publication should have a canonical companion post** on your site that's longer, more detailed, and links to the external version. You should be the definitive source, not AppSignal.

**6. Add structured data, fix meta tags, update the site title.** These are table stakes, not optional.

The site has a strong foundation in terms of domain age and your genuine expertise. But right now it reads like a developer's blog that's been passively maintained for a decade, not like the professional presence of a CTO building companies. The gap between your actual credibility and what this site communicates is the biggest problem to solve.