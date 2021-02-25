%{
title: 'Neural Networks Without a PhD: Topologies',
category: 'Programming',
tags: ['machine learning','programming','neural networks'],
description: "A series focused on presenting Neural Networks and the related concepts in layman's terms, that is to say without specialized knowledge in math or machine learning."
}
---

> Topology of a neural network refers to the way the Neurons are connected, and it is an important factor in network functioning and learning. A common topology in unsupervised learning is a direct mapping of inputs to a collection of units that represents categories (e.g., Self-organizing maps).
> -- [Springer](https://link.springer.com/referenceworkentry/10.1007%2F978-0-387-30164-8_837)

In our previous post we learned about the components that form a neural network:

- Input Nodes
- Neurons
- Output Nodes

as well that those elements will be organized in the following layers:

- Input Layer
- Hidden Layers
- Output Layer

However, it still not very clear what the process for organizing and connecting those neural networks is; how do we determine how many hidden layers we need to create? How do we connect those neurons to the inputs, outputs and to each other? How do we know how many output nodes we need to create?

## How to organize our Neural Network

What we need is a way to represent how neurons are connected in order to form a network, a **Neural Network Topology**. The topology of a neural network plays an essential role in its function and performance.

An important thing to notice is that **multiple topologies** can be used to learn the same set of data, and they are even likely to produce similar results; and as such there is not 'best' topology for a single neural network; that being said topology can greatly impact the amount of time required for a neural network to learn data as well its accuracy when classifying new data.

{% excerpt %}
One a approach to topology selection is to simply make it a trial and error process, where we manually tweak the Neural network by modifying things like the number of **hidden layers**, **connections between nodes,** and so on. Taking this approach would limit us greatly as there are many possible permutations even for a **simple neural network**; to complicate matters even further, Neural networks are not limited to the relatively simple **Feed-Forward** layout we have seen before, to mention a few:
{% endexcerpt %}

- Feed-forward
- Recurrent
- Long Short Term Memory
- Jordan
- Elman
- Hopfield

![Network types - Source: turingfinance.com](https://www.turingfinance.com/wp-content/uploads/2014/04/Recurrent-Neural-Network-Architectures.png)

So outside of very simple applications, known problems or learning exercises **manual topology selection** is not a viable option, in order to find the ideal topology we have to let our neural network to learn the topology from the training data as well. The goal is to find a topology for our neural network that **minimizes the the error on new data. **

One of most novel approaches for this objective is the use of genetic programming.

## Genetic Programming and Neuro Evolution

Genetic algorithms are based on the evolutionary principles of the **natural selection**, **mutation** and **survival of the fittest**; a genetic algorithm will approach a particular problem by generating a large number of potential solutions and finding the solutions with the best **fitness score**.

Without going too deep into the weeds, a **fitness score** is a method to measure how close was the solution to known result or to a expected metric; in the case of a neural network where we have training data that we can use as reference point.

The Genetic algorithm will tweak and mutate our neural network generation after generation until the desired fitness score is achieved or until we reach the maximum number of iterations.

**Disclaimer: The above is a oversimplified description of how genetic algorithms work**

I highly recommend, [The Handbook of Neuroevolution through Erlang](https://link.springer.com/book/10.1007/978-1-4614-4463-3) for an amazing breakdown of the subject, even if you are not into Erlang the author makes a terrific job on breaking down the concepts and introduction genetic algorithms.

# Summary

I'm important that we understand how topology, that is the **number of layers and how they are connect** of our neural networks can impact their effectiveness; there are many existing types of artificial neural networks some best suited to particular tasks of applications, and is important to familiarize ourselves with the most common types.

Additional, in order to find the optimal topology one can use **Genetic algorithms** in order to try to evolve the **'perfect'** topology for a given application.

There is still a lot more to learn and go, but feel free to **leave a comment** if you find any factual errors or if you think something **needs more clarification**.
