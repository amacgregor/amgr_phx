%{
title: "Phoenix Contexts Done Right",
category: "Programming",
tags: ["elixir", "phoenix", "architecture", "domain-driven-design"],
description: "When to split contexts, cross-context communication, and avoiding the god context anti-pattern",
published: false
}
---

Phoenix contexts are one of the most misunderstood features in the framework. Developers either ignore them entirely, dumping everything into a single module, or they over-engineer boundaries that create more friction than value. Both paths lead to the same destination: a codebase that fights you at every turn.

The problem is not contexts themselves. The problem is that most tutorials show you *how* to generate a context without explaining *why* you would want one. Context generators are training wheels. At some point, you need to understand the bicycle.

---

## What Contexts Actually Solve

Phoenix contexts are the framework's implementation of bounded contexts from Domain-Driven Design. The concept originates from Eric Evans' seminal work, where he observed that large systems inevitably contain multiple conceptual models. A "user" in your billing system is not the same as a "user" in your authentication system. They share an identifier, but their behaviors, attributes, and invariants differ.

Contexts provide explicit boundaries around these conceptual models. They define a public API for a specific domain and hide the implementation details behind it. When you call `Accounts.create_user/1`, you do not care whether it uses Ecto, talks to an external service, or writes to a flat file. You care about the contract.

This is not about organizing files into folders. It is about defining seams in your application where change can happen independently. A well-designed context boundary means you can rewrite the internals of your billing system without touching authentication. You can swap out your payment processor without modifying your order management logic.

The Phoenix generators create contexts by default because Chris McCord and the core team understand something that takes most developers years to learn: the cost of extracting boundaries later is an order of magnitude higher than establishing them early. The question is not whether to use contexts. The question is where to draw the lines.

---

## Signs You Need to Split a Context

The initial context the generator creates is a starting point, not a destination. As your application grows, you will encounter signals that a context has exceeded its natural boundaries. Recognizing these signals early prevents the architectural debt that compounds over time.

### Size and Cognitive Load

When a context file exceeds 500 lines, something has gone wrong. Not because 500 is a magic number, but because a single module should represent a coherent concept that fits in your head. If you cannot explain what `Accounts` does in one sentence, it is doing too much.

I have seen context files balloon to 2,000 lines. At that point, developers stop reading the module. They search for the function they need, make their change, and leave. No one maintains a mental model of the whole. The context becomes a dumping ground.

### Coupling Between Unrelated Operations

Examine the function signatures in your context. If half of them take a `%User{}` struct and the other half take an `%Organization{}` struct, you likely have two contexts masquerading as one. The tell is when changes to user-related functions require you to understand organization-related code, or vice versa.

```elixir
# Before: Mixed concerns in a single context
defmodule MyApp.Accounts do
  def create_user(attrs), do: # ...
  def update_user(user, attrs), do: # ...
  def create_organization(attrs), do: # ...
  def add_member(organization, user), do: # ...
  def update_billing_info(organization, attrs), do: # ...
  def list_invoices(organization), do: # ...
end
```

This module handles user management, organization management, membership, and billing. Each of these has distinct invariants and change frequencies. Billing logic changes when you switch payment providers. User logic changes when you add authentication methods. Coupling them means coordinating unrelated changes.

### Team Boundaries

Conway's Law applies to contexts. If two teams own different parts of a context, you will experience friction. Pull request conflicts, unclear ownership, and divergent conventions emerge. Context boundaries should align with team boundaries when possible.

This does not mean one team per context. It means a context should not be split across teams. A single team can own multiple contexts. Multiple teams sharing one context invites chaos.

### Different Data Lifecycles

Some data is transactional and changes frequently. Other data is reference data that changes rarely. When your context mixes both, you end up with awkward caching strategies and unclear consistency guarantees.

A product catalog and an order system have fundamentally different lifecycles. Products are created occasionally and read constantly. Orders are created constantly and rarely modified after completion. Combining them in a single `Commerce` context obscures these differences.

---

## Cross-Context Communication Patterns

Once you split contexts, they need to talk to each other. This is where many teams stumble. They either create tight coupling that defeats the purpose of separation, or they over-engineer event systems that add complexity without benefit. There are three primary patterns, each with appropriate use cases.

### Direct Function Calls

The simplest approach is direct function calls between contexts. Context A calls a public function on Context B. This is appropriate when the dependency is clear and unidirectional.

```elixir
defmodule MyApp.Orders do
  alias MyApp.Accounts
  alias MyApp.Inventory

  def create_order(user_id, items) do
    with {:ok, user} <- Accounts.get_user(user_id),
         :ok <- Inventory.reserve_items(items),
         {:ok, order} <- do_create_order(user, items) do
      {:ok, order}
    end
  end
end
```

The Orders context depends on Accounts and Inventory. It knows they exist. It calls their public functions. This is fine when:

- The dependency is stable and unlikely to change
- The operation requires synchronous responses
- Failure in the dependency should fail the entire operation

Do not overthink this. Direct calls are not evil. They are the right choice when you need a synchronous, transactional operation that spans contexts.

### Domain Events

When operations in one context should trigger reactions in other contexts without tight coupling, domain events are the appropriate pattern. The source context publishes an event. Interested contexts subscribe and react.

```elixir
defmodule MyApp.Orders do
  alias MyApp.Events

  def complete_order(order) do
    with {:ok, order} <- do_complete_order(order) do
      Events.publish(%OrderCompleted{
        order_id: order.id,
        user_id: order.user_id,
        total: order.total
      })
      {:ok, order}
    end
  end
end

defmodule MyApp.Notifications do
  use MyApp.Events.Subscriber

  def handle_event(%OrderCompleted{} = event) do
    send_order_confirmation_email(event.user_id, event.order_id)
  end
end

defmodule MyApp.Analytics do
  use MyApp.Events.Subscriber

  def handle_event(%OrderCompleted{} = event) do
    track_purchase(event.user_id, event.total)
  end
end
```

Orders does not know about Notifications or Analytics. It publishes what happened. Other contexts decide how to react. This is appropriate when:

- Multiple contexts need to react to the same event
- The reactions can happen asynchronously
- The source context should not fail if a subscriber fails

Phoenix PubSub provides the infrastructure for in-process events. For durability and cross-node delivery, tools like Broadway with a message queue backend provide stronger guarantees.

### Shared Schemas: Handle With Care

Sometimes two contexts need to read the same data. The question is whether they should share an Ecto schema or define their own.

Shared schemas create coupling. When Context A and Context B both use `%User{}`, changes to that schema affect both. This is sometimes acceptable, sometimes not.

A useful heuristic: share schemas when both contexts need the same view of the data. Define separate schemas when they need different views.

```elixir
# Shared: Both contexts need the same user data
defmodule MyApp.Accounts.User do
  use Ecto.Schema

  schema "users" do
    field :email, :string
    field :name, :string
    field :hashed_password, :string
    timestamps()
  end
end

# Separate: Analytics needs a different view
defmodule MyApp.Analytics.UserProfile do
  use Ecto.Schema

  @primary_key false
  schema "users" do
    field :id, :integer
    field :created_at, :utc_datetime, source: :inserted_at
    # No password field - Analytics should not see it
  end
end
```

The Analytics context reads from the same table but defines only the fields it needs. It cannot accidentally expose password hashes. It cannot accidentally depend on fields that might change. The coupling is explicit and minimal.

---

## The God Context Anti-Pattern

Every Phoenix application I have inherited has at least one god context. It starts innocently. The team generates a context, adds features, and keeps adding. Six months later, `lib/my_app/accounts.ex` is 1,800 lines and imports half the application.

The god context exhibits specific symptoms:

1. **Everything depends on it.** Draw a dependency graph of your contexts. If one node has arrows pointing to every other node, you have a god context.

2. **It changes constantly.** Check your git history. If one file appears in 60% of your commits, that file is doing too much.

3. **It has no clear responsibility.** Ask three developers what the context does. If you get three different answers, the context has no identity.

4. **Tests are slow and brittle.** God contexts require extensive setup because they touch everything. Tests break when unrelated features change.

### Refactoring Out of the God Context

Escaping the god context requires surgery. You cannot do it in one pull request. The strategy is incremental extraction: identify a cohesive subset, extract it, redirect callers, delete the old code.

**Step 1: Identify extraction candidates.**

Group functions by the primary entity they operate on. If fifteen functions take a `%User{}` as the first argument and ten functions take an `%Organization{}`, you have two candidate contexts.

**Step 2: Define the new context boundary.**

Create the new module with the functions you are extracting. Initially, these can delegate to the old implementations.

```elixir
defmodule MyApp.Organizations do
  @moduledoc """
  Manages organizations and their settings.
  """

  # Temporary delegation during migration
  defdelegate create_organization(attrs), to: MyApp.Accounts
  defdelegate update_organization(org, attrs), to: MyApp.Accounts
  defdelegate get_organization(id), to: MyApp.Accounts
end
```

**Step 3: Migrate callers.**

Update call sites throughout your application to use the new context. This is mechanical work but reveals hidden dependencies. When you find a controller calling `Accounts.create_organization/1`, change it to `Organizations.create_organization/1`.

**Step 4: Move the implementation.**

Once all callers use the new context, move the actual implementation. Extract the relevant schemas, queries, and business logic.

```elixir
defmodule MyApp.Organizations do
  alias MyApp.Organizations.Organization
  alias MyApp.Repo

  def create_organization(attrs) do
    %Organization{}
    |> Organization.changeset(attrs)
    |> Repo.insert()
  end

  def update_organization(%Organization{} = org, attrs) do
    org
    |> Organization.changeset(attrs)
    |> Repo.update()
  end

  def get_organization(id) do
    Repo.get(Organization, id)
  end
end
```

**Step 5: Delete the old code.**

Remove the delegations, the old functions, and any schemas that moved entirely. Run your tests. Ship it.

This process takes time. On a large codebase, extracting a single context might span multiple sprints. That is acceptable. Rushed extractions create new problems. Incremental, tested changes compound into a clean architecture.

---

## A Refactoring Case Study

Consider a real scenario. You have an e-commerce application with a single `Shop` context. Over eighteen months, it grew to include:

- User registration and authentication
- Product catalog management
- Shopping cart operations
- Order processing
- Payment handling
- Inventory tracking
- Shipping calculations
- Customer support tickets

The `Shop` module is 2,400 lines. Tests take forty-five seconds. Developers avoid touching it. New features take three times longer than they should because understanding the blast radius of any change requires reading thousands of lines.

Here is how you decompose it:

```elixir
# Before: The god context
defmodule MyApp.Shop do
  # 2,400 lines of everything
  def register_user(attrs), do: # ...
  def authenticate(email, password), do: # ...
  def list_products(filters), do: # ...
  def add_to_cart(user, product, qty), do: # ...
  def checkout(cart, payment_info), do: # ...
  def process_payment(order, payment), do: # ...
  def update_inventory(product, qty), do: # ...
  def calculate_shipping(order, address), do: # ...
  def create_ticket(user, subject, body), do: # ...
  # ... 100+ more functions
end
```

```elixir
# After: Decomposed into focused contexts

defmodule MyApp.Accounts do
  @moduledoc "User registration, authentication, and profile management."
  def register_user(attrs), do: # ...
  def authenticate(email, password), do: # ...
  def get_user(id), do: # ...
end

defmodule MyApp.Catalog do
  @moduledoc "Product listings, categories, and search."
  def list_products(filters \\ []), do: # ...
  def get_product(id), do: # ...
  def search_products(query), do: # ...
end

defmodule MyApp.Cart do
  @moduledoc "Shopping cart operations."
  alias MyApp.Catalog

  def add_item(cart, product_id, quantity) do
    with {:ok, product} <- Catalog.get_product(product_id),
         :ok <- validate_availability(product, quantity) do
      do_add_item(cart, product, quantity)
    end
  end

  def remove_item(cart, product_id), do: # ...
  def get_cart(user_id), do: # ...
end

defmodule MyApp.Orders do
  @moduledoc "Order creation, status, and history."
  alias MyApp.{Cart, Payments, Inventory}

  def create_order(cart, shipping_address) do
    Repo.transaction(fn ->
      with {:ok, order} <- build_order(cart, shipping_address),
           {:ok, _} <- Inventory.reserve(order.items),
           {:ok, order} <- Repo.insert(order) do
        order
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end
end

defmodule MyApp.Payments do
  @moduledoc "Payment processing and refunds."
  def process(order, payment_method), do: # ...
  def refund(payment, amount), do: # ...
end

defmodule MyApp.Inventory do
  @moduledoc "Stock levels and reservations."
  def reserve(items), do: # ...
  def release(items), do: # ...
  def update_stock(product_id, quantity), do: # ...
end

defmodule MyApp.Shipping do
  @moduledoc "Shipping calculations and carrier integration."
  def calculate_rates(order, address), do: # ...
  def create_shipment(order), do: # ...
end

defmodule MyApp.Support do
  @moduledoc "Customer support tickets."
  def create_ticket(user_id, subject, body), do: # ...
  def list_tickets(user_id), do: # ...
  def respond_to_ticket(ticket_id, response), do: # ...
end
```

Each context now has a clear responsibility. Each can be understood in isolation. Each can change independently. The dependency graph is explicit: Orders depends on Cart, Payments, and Inventory. Cart depends on Catalog. Support depends on nothing.

Tests become faster because you test each context with minimal setup. New developers onboard faster because they can understand one context at a time. The team moves faster because changes are localized.

---

## Practical Guidelines

After years of building Phoenix applications, these guidelines have proven reliable:

**Start with the generators.** Let Phoenix create initial contexts. You can always split later, but establishing *some* boundary is better than none.

**Name contexts after business concepts, not technical ones.** `Accounts`, `Billing`, `Inventory` are good. `Database`, `External`, `Helpers` are not.

**Keep context APIs small.** If a context has fifty public functions, it is doing too much. Aim for ten to fifteen.

**Avoid circular dependencies.** If Context A depends on Context B and B depends on A, you have not found the right boundaries. Extract a third context or use events to break the cycle.

**Accept some duplication.** Two contexts with similar helper functions are better than two contexts coupled through a shared utility module. Duplication is cheaper than coupling.

**Test contexts in isolation.** Each context should have tests that do not require other contexts to be set up. If you cannot test Orders without setting up the entire Accounts context, your boundaries are wrong.

Context design is not a one-time decision. It evolves as your understanding of the domain deepens. The codebase you ship in month three will not have the same boundaries as month eighteen. That is expected. Good architecture is not about getting it right the first time. It is about making change cheap when you learn you were wrong.

---

## Key Claims to Verify

- The 500-line threshold for context complexity is a heuristic based on practical experience; your team may have different tolerances
- Phoenix PubSub and Broadway are referenced as event infrastructure options; verify current best practices in the Phoenix ecosystem
- The refactoring case study is a composite example; specific metrics like "45 seconds" for tests are illustrative
