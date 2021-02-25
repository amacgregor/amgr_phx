%{
title: "Design Patterns in PHP: Adapters",
category: 'Programming',
tags: ['programming','design patterns','PHP'],
description: "The adapter pattern also referred as the wrapper pattern, I find that wrapper is a more fitting name since it describes clearly what this pattern does; it encapsulates the functionality of a class or object into a class with a common public interfaces."
}
---

The **adapter pattern** also referred as the wrapper pattern, I find that wrapper is a more fitting name since it describes clearly what this pattern does; it encapsulates the functionality of a class or object into a class with a common public interfaces.

> In software engineering, the adapter pattern is a software design pattern that allows the interface of an existing class to be used for another interface.[1] It is often used to make existing classes work with others without modifying their source code.

Adapters are one of the easiest patterns to comprehend and at the same time one of the most useful ones. Strangely enough documentation and examples for this particular pattern seems to be somewhat lacking in the **PHP world** (at least as far as the research for this article took me) so I'll try to provide examples that are closer to real world usages.

But first, we need to go over some basic concepts about this pattern. As with any pattern, the adapter pattern has multiple participants:

- **Client:** The client is a class or object that wants to consume the Adaptee public API.
- **Adapter:** The adapter provides a common interface between the adaptee and its clients.
- **Adaptee:** The adaptee is an object from a different module or library.

Another advantage of the adapter pattern is that allows us to **decouple our client code from the adaptee implementations**. Let's see what that means in the following example:

In our example we will work with a notification manager class:

<script src="https://gist.github.com/amacgregor/170d1b99e12bd3b12ca6.js"></script>

Although the previous example is oversimplified, it illustrates clearly were adapters can be useful, so let's breakdown the problems with the notificationManager class.

- The class knows too much about each notification type implementation.
- If any of the notification classes change, we have to change our NotificationManager class code.
- Adding a new notification type requires modifying the NotificationManager class code.

Regardless of the notification service being used we know that our notification class should do two things:

- Accept the data from the NotificationManager
- Send a notification

How the data is parsed, and the notification send is completely up to the service implementation; so based on that we can start by creating a **NotificationInterface** class:

<script src="https://gist.github.com/amacgregor/894ee4e24975c537a191.js"></script>

The notification interface will be implemented by each and one of our notification adapters:

<script src="https://gist.github.com/amacgregor/85108283f3ca51156bdd.js"></script>

Based on the code above we can now rewrite our NotificationManager class in the following way:

<script src="https://gist.github.com/amacgregor/27e6048d8f969ec59d30.js"></script>

Doesn't that look better? As long as the notification services implement the _NotificationInterface_ the notification manager doesn't need worry about the specifics of each implementation.

However, there is still a problem with the _NotificationManager_ class:

- Adding a new notification type requires modifying the NotificationManager class code.

Fortunately, this can be solve easily if we use the **Dependency Inversion Principle** and since this is a bit out of the scope of this article, I won't go into much detail about the specifics of this principle.

> In object-oriented programming, the dependency inversion principle refers to a specific form of decoupling software modules.

<script src="https://gist.github.com/amacgregor/0fc56114ea4fba62d9e1.js"></script>

Thanks to the use of adapters for the notification services, we can decouple of the notificationManager even more.

## Summary

Adapters are extremely useful when combined with **SOLID design principles** and help developers to write cleaner and more maintainable code.
