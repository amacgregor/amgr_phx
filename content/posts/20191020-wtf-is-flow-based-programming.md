%{
title: "WTF is Flow-Based Programming",
category: "Programming",
tags: ["programming","functional programming","flow-based programming","software architecture"],
description: "A quick introduction and overview on the ideas behind Flow-Based Programming"
}
---

> In computer programming, flow-based programming (FBP) is a programming paradigm that defines applications as networks of "black box" processes, which exchange data across predefined connections by message passing, where the connections are specified externally to the processes. These black box processes can be reconnected endlessly to form different applications without having to be changed internally. – [Wikipedia](https://en.wikipedia.org/wiki/Flow-based_programming)

<!--A quick introduction and overview on the ideas behind Flow-Based Programming-->

As a software developer, I'm always trying different programming languages, different styles and distinct **paradigms**: procedural, OOP, functional, and recently I got introduced to a curious and different approach for software design – **Flow-Based Programming (FBP).**

**Flow-Base Programming** defines an application as a network of independent process exchanging data through message passing. **FBP** is a data first approach, in which the application is viewed as a system of data pipelines being transformed by the process.

![Data Processing Belt Line](/images/posts/conveyer-belt.jpg)

## Data Processing Factories

Back in 2017 I had the opportunity to meet with [J. Paul Morrison](https://jpaulm.github.io/index.html) the inventor/discoverer behind FBP, and way that he explained the general idea behind FBP is to think about application as a **data processing factory** where data moves as part of a conveyor belt system and each process is an independent "black box" with one or more inputs and outputs.

Connections between process are predefined and externally to the process itself.

### Key Concepts

- Applications are broken down into **repeatable individual components**.
- **Connections** between components are handled externally
- Components are **blackboxes** to each other
- **Data-centric approach,** think about the application as a series of transformations to the data

## Summary

Overall, the fact that FBP forces the idea of compartmentalized logic and a data first approach makes FBP an extremely powerful tool on your developer arsenal when correctly applied.

In subsequent articles will go into more detail of the advantages, disadvantages, and implementation options for you to start experimenting with **Flow-Based Programming.**
