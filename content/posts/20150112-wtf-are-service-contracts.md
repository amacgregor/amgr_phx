%{
title: "WTF are: Service Contracts (Magento 2 Edition)",
category: "Programming",
tags: ["programming","magento","service contracts","design patterns"],
description: "The Service layer allows modules to provide a well-defined public API and effectively hiding the business logic and preserving data integrity."
}
---

Now that Magento2 beta has been officially released, you are probably wondering
what the hell are **Service Contracts** and more importantly why the hell do you
need them.

But before we jump into the nitty-gritty of service contracts let's get this out
of the way:

<p style="text-align:center"><img style="display:inline-block" src="https://i.imgur.com/m7oagqw.jpg" width="100%" alt="Magento Service Contracts is people"/></p>

Yes, Service contracts are nothing more than a set of interfaces used to define
the public api of a module.

Now, is important to clarify that by API we are talking about the set of
interfaces that a module provides to other modules to access their
implementations.

# Service Contract Architecture

> In Magento the service layer provides a formal contract between a client and
> the service provider. This form of contact allows evolution of a service
> implementation without affecting the client.

The Service layer allows modules to provide a well-defined public API and
effectively hiding the business logic and preserving data integrity.

Magento 2 service layer is comprised of two types of interfaces, Data Interfaces
and Service Interfaces. Data Interfaces are immutable data objects that allow to
preserve data integrity by implementing the following patterns:

- They define only constants and/or getters, meaning they are read-only.
- Getter functions **must** have no parameters.
- A getter function **must** only return one of the following objects types:
  - A simple type (integer, string, boolean)
  - An Array of a simple type
  - Another Data interface
  - Getter functions cannot return mixed types.
  - Data interfaces can only be populated or modified by using data entity builders.

Service Interfaces, on the other hand, are in charge of providing a
stable set of public methods that can be used with by the clients
regardless of the kind (controller, the web service, other Magento
modules)

Service interfaces differ a bit from their Data counter parts; we have
three subtypes of service interfaces:

- Repository Interfaces
- Management Interfaces
- Metadata Interfaces

### Repository Interfaces

Repository interfaces are used to provide access to the persistent data
entities, all this means is that they provide a specific set of methods interact
with the data objects.

Repositories abstract the way data is mapped out to an object, this way the data
storage(database) could be anything, and could change without affecting the
clients (other modules).

Repository interfaces should implement the following methods:

- save
- get
- getList
- delete
- deleteById

For each data entity, we have a corresponding data interface. But, if that
wasn't
clear enough, let's go ahead and see a couple of examples of how Magento2 makes
use of Repository interfaces.

<script src="https://gist.github.com/amacgregor/dec3eab91cc7858189dc.js"></script>

Ok, so that the interface definition but how is used? Let's take a
look at another class from the customer module.

<script src="https://gist.github.com/amacgregor/ca2a9a1f93e062998b31.js"></script>

For now let's not worry about how the customerRepository object is instantiated
(we will deal with that later on another post about the objectManager)
but how is being used, in particular we want to look at the
following function:

<script src="https://gist.github.com/amacgregor/497d247b9d34b47e487a.js"></script>

### Why is it Great?

With Magento 2 use of the repository pattern, we could add a new customer
extension, that changes the model and the resource model, to let's, say save
customer date into a MongoDB and as long that new customer model implements the
necessary service interfaces we can be certain that we are not breaking the res
of the application.

I will cover the rest of the interface types once the Magento2 documentation is
updated and there are more details on their specific responsibilities.
