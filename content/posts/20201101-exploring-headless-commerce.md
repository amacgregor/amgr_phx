%{
title: "Exploring Headless Commerce",
category: "Technology",
tags: ["e-commerce","headless","technology"],
description: 'Exploring the current state of headless commerce and how to best take advantage'
}
---

<!--Exploring the current state of headless commerce and how to best take advantage-->

One of the interesting side effects of the [COVID-19](https://retail-insider.com/retail-insider/2020/7/retail-e-commerce-explodes-in-canada-amid-covid-19-pandemic/) pandemic is the unprecedented [acceleration](https://techcrunch.com/2020/08/24/covid-19-pandemic-accelerated-shift-to-e-commerce-by-5-years-new-report-says/) and [adoption](https://www.bigcommerce.com/blog/covid-19-ecommerce/) of ecommerce by many companies.

However, is my experience that **headless commerce** is a very abused term and as someone brilliantly put it:

> **Headless Commerce** is like teenage sex: everyone talks about it, nobody really knows how to do it, everyone thinks everyone else is doing it, sp everyone claims they are doing it.

The purpose of this article is to explore a bit of the general concepts of Headless commerce as well review some of the available technologies and platforms available for implementing a headless commerce solution.

## What is Headless Commerce?

![Basic Headless Architecture](/images/posts/basic-headless-architecture.png)

> At it's core every ecommerce website is composed of two functional halves, the frontend which handles the presentation layer and the backend that handless the business logic.

Traditionally, both systems are tightly coupled meaning both the frontend and the backend are developed and served by the same framework/platform.

At its core, **headless commerce** is an architecture pattern that decouples the presentation logic from the e-commerce backend system that handles things like inventory, order fulfillment, payments, etc.

It helps to think of headless commerce as a strategy for building your ecommerce solution rather than a particular technology or approach, as headless commerce can be implemented in several different ways.

## Why use Headless Commerce?

> Headless can open up a world of possibility from a client acquisition standpoint, as well as a way to offer more digital ecommerce options.

Headless commerce promises a variety of benefits:

- Customizability
- Speed
- Scale
- Control

More importantly, a headless approach gives us the ability to provide customers with more individualized and personal experiences.

Having the **frontend decoupled can drastically increase the speed of development** to launch new features without having to touch the heavy and often expensive backend logic.

Having an independent frontend, allows brands to implement completely different strategies to present and market their products, for example, a **content-first strategy** where the transactional aspects are secondary and a high amount of emphasis is put on the content about the product.

## Technology

Now to the fun part, implementation. For the purpose of this initial article, I won't into full detail on the implementation details rather the following is a list of available solutions that are currently available on the market.

### Frontend Technologies

The following is a non-exhaustive list of solutions for building ecommerce presentation layers and storefronts.

**Vue Storefront** [website](https://www.vuestorefront.io/)

> Vue Storefront is the open-source frontend for any eCommerce, built with a PWA and headless approach, using a modern JS stack.

Vue Storefront is probably one of the first, if not the first Headless commerce framework as well as the first PWA one.

One of the main advantages of **Vue Storefront** is that can work with any ecommerce backend and provides adapters for some of the most popular ones like:

- Magento
- Shopify
- BigCommerce
- commercetools

**Front-Commerce** [website](https://www.front-commerce.com/en/)

> Front-Commerce is a layer that gathers data from your eCommerce backend and related services to directly serve pages to consumers

Front-commerce has been around since 2018, and like **Vue Storefront** they are PWA storefront, but with a strong focus on Magento 1 and Magento 2.

**Next.js Commerce** [website](https://nextjs.org/commerce)

> The all-in-one starter kit for high-performance e-commerce sites.

Next.js commerce by [vercel](https://vercel.com/) is fairly new but looks extremely promising. Right now it can only support BigCommerce as its backend but other backends are on the roadmap.

Additionally, this project is opensource so you can follow the development on their [Github](https://github.com/vercel/commerce)

### Backend Technologies

The following is a non-exhaustive list of solutions for building ecommerce backends, which can include catalogs, payments, content management, inventory, order management, and so on.

**BigCommerce** [website](https://www.bigcommerce.ca/)

> BigCommerce is a SaaS ecommerce platform that provides some headless capabilities.

While BigCommerce is and started as an all-in-one solution they offer one of the most extensive supports for building headless ecommerce implementations and constantly adding more to the mix.

Their official documentation [Developers Guide to Headless Commerce](https://developer.bigcommerce.com/api-docs/storefronts/developers-guide-headless) offers a variety of approaches for implementing a solution:

- Headless without coding
- Custom solution but without building from scratch
- Extend an existing solution or build from scratch

**Commercetools** [website](https://commercetools.com/)

> commercetools is a next-generation ecommerce platform build with a headless first approach and on a microservices architecture.

While commercetools is aimed at medium to large-sized companies, it is definitely an option to consider due to its API first and headless focused architecture as well its ability to scale and and extensive set of functionality.

One thing to keep in mind about **Commercetools** is that both the licensing and implementation cost will be prohibitive for some of the smaller merchants.

**Nacelle commerce** [website](https://getnacelle.com/)

> Nacelle is a headless eCommerce platform made for developers who want to create superior customer buying experiences.

Nacelle is one of the most interesting options I stumbled on while doing research for this article. Nacelle market's itself as a headless commerce platform, but in reality, it would be more appropriate to call them a middleware.

**Nacelle** handles the data flow between your back end to your PWAs and custom applications; which in my opinion fits perfectly the definition of middleware, and unlike the other two previous options you will still need your products and ecommerce backend set up in one of the following two platforms:

- Magento
- Shopify

Still, Nacelle in my opinion makes it a perfect solution for merchants looking to transition to a headless strategy without fully having to replatform.

### References

- [HeadlessCommerce](https://headlesscommerce.org)

<!-- Research: https://headlesscommerce.org/
- [Frontcommerce](https://www.front-commerce.com/en/front-commerce-a-modern-ecommerce-architecture/)
- [Deity Falcon](https://github.com/deity-io/falcon)
- [Commerce Layer](https://commercelayer.io/platform/)
- [Commerce Tools](https://commercetools.com/headless-commerce)
- [Swell Commerce](https://www.swell.is/)
-->
