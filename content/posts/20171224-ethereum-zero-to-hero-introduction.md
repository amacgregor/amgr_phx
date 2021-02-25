%{
title: 'Ethereum Zero to Hero: Introduction',
category: 'Blockchain',
tags: ['blockchain','programming','ethereum'],
description: 'An introduction to Ethereum Development'
}
---

2017 has arguably been the year of Cryptocurrency, with **Bitcoin** being getting most of the spotlight; at the core of Bitcoin, we have the **Blockchain**.

Blockchain technology applications go way beyond digital currency, and one of the best examples is **Ethereum** which is a decentralized platform that runs smart contracts.

This allows developers to build enormously powerful decentralized applications, at this point there is still a lot of active development and innovation happening both around blockchain and ethereum.

The downside of all this constant innovation and development is that tutorials, documentation, and resources go out of date quickly, this has made it difficult for developers like me (or you) to get a solid footing when getting started.

**This guide is not to mean to the end all or be all**, rather a quick introduction that can get you started quickly and hopefully agnostic enough that won't go out of date too fast. With that said, let's get started by reviewing some core concepts:

### Smart Contracts

> Contracts live on the blockchain in an Ethereum-specific binary format (EVM bytecode).

A smart contract is a piece of software that resides on the **Ethereum** Blockchain. Like traditional contracts, smart contacts not only define the rules and penalties around an agreement but additionally the enforce those obligations.

### Ethereum Virtual Machine

> At the heart of it is the Ethereum Virtual Machine (“EVM”), which can execute code of arbitrary algorithmic complexity. In computer science terms, Ethereum is “Turing complete.”

This is the core and primary innovation behind the Ethereum project. Each participant of the **Ethereum** networks runs an instance of the virtual machine, and its purpose is to execute the smart contracts in a completely isolated environment, meaning no access to Network, Filesystem or other processes.

### Gas

Gas is a concept unique to the ethereum platform and is way to limit the resources available to a given smart contract. For every instruction executed in the EVM, there is a fixed Gas cost associated with it.

### Solidity

Solidity is a contact-oriented, high-level language for implementing smart contracts. The syntax resembles javascript and is influenced by languages like C++ and Python, and it compiles directly to EVM assembly.

### Blockchain

> “The blockchain is an incorruptible digital ledger of economic transactions that can be programmed to record not just financial transactions but virtually everything of value.” - Don & Alex Tapscott, authors Blockchain Revolution (2016)

The best way to think about the blockchain is as decentralized **immutable database** or ledger, that can permanently store any type data.

The potential business applications for this technology are still being discovered and experimented with, but there are tons of examples online, to mention a few we have:

- Crowdfunding
- Governance
- File Storage
- Protection of Intellectual Property
- Identity Management
- Property Registration

In the next entry in this series we will set up a local development environment for creating our first **smart contract.**
