%{
title: "The Ash Framework: A Practical Introduction",
category: "Programming",
tags: ["elixir", "ash", "framework", "domain-driven-design"],
description: "Domains, resources, actions, and policies - when Ash makes sense",
published: false
}
---

# The Ash Framework: A Practical Introduction

Every Elixir application eventually faces the same inflection point. Your Phoenix contexts grow fat with business logic. Your Ecto schemas sprout validation functions that duplicate authorization checks scattered across controllers. You write the same CRUD operations for the fifteenth time, each slightly different, each accumulating its own quirks.

Ash Framework offers a different path. It is a declarative toolkit for modeling your domain — your resources, their relationships, their behaviors, and who can do what to whom. The pitch is seductive: describe what your domain looks like, and Ash generates the implementation.

But seductive pitches deserve scrutiny. Let me show you what Ash actually is, when it earns its place in your stack, and when plain Phoenix and Ecto remain the better choice.

## What Ash Actually Is

Ash is not a replacement for Phoenix or Ecto. It sits above them, orchestrating them. Think of it as a domain modeling layer that compiles down to the primitives you already know.

At its core, Ash inverts the typical application architecture. Instead of writing imperative code that manipulates data, you declare resources — their attributes, relationships, actions, and policies. Ash reads these declarations and generates the machinery to execute them.

This is not code generation in the traditional sense. You do not run a generator and edit the output. The declarations are the source of truth. Change the declaration, and the behavior changes.

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false
    attribute :body, :string, allow_nil?: false
    attribute :status, :atom, constraints: [one_of: [:draft, :published, :archived]]
    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :body]
      change set_attribute(:status, :draft)
    end

    update :publish do
      change set_attribute(:status, :published)
    end
  end
end
```

That is a complete, functional resource. It has a database schema, validation, default actions, and a custom `publish` action. No controller code. No context module with boilerplate CRUD functions. Just a declaration.

## Core Concepts: The Four Pillars

Ash organizes around four interlocking concepts. Understanding their relationships is essential before you write a line of code.

### Domains

A Domain groups related resources. It is the public API boundary for a portion of your application. If you are familiar with Phoenix contexts, Domains serve a similar architectural role — but with teeth.

```elixir
defmodule MyApp.Blog do
  use Ash.Domain

  resources do
    resource MyApp.Blog.Post
    resource MyApp.Blog.Comment
    resource MyApp.Blog.Author
  end
end
```

You interact with resources through their domain. `MyApp.Blog.read!(MyApp.Blog.Post)` reads posts. The domain enforces that you cannot accidentally bypass authorization or skip validations by calling resources directly.

### Resources

Resources are the nouns of your system. A Post. A User. An Order. Each resource declares its attributes (the data it holds), relationships (how it connects to other resources), and actions (what you can do with it).

Resources do not contain business logic in the traditional sense. They contain declarations that Ash interprets to produce behavior.

### Actions

Actions are the verbs. Every interaction with a resource happens through an action. Ash provides five action types:

- **create**: Produces new records
- **read**: Queries existing records
- **update**: Modifies existing records
- **destroy**: Removes records
- **action**: Generic actions that do not map to CRUD — sending emails, triggering webhooks, computing derived values

Actions are not methods you implement. They are configurations you declare. Ash provides the execution engine.

### Policies

Policies answer the question: who can do what? They are declarative authorization rules attached to resources and actions.

```elixir
policies do
  policy action_type(:read) do
    authorize_if expr(status == :published)
    authorize_if actor_attribute_equals(:role, :admin)
  end
end
```

This policy reads: allow reads if the post is published, OR if the actor is an admin. Policies compose. They can reference the actor, the data being accessed, and the context of the request.

## Defining Resources: Attributes and Relationships

Let me build a more complete example. A blog system with authors, posts, and comments.

```elixir
defmodule MyApp.Blog.Author do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "authors"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :email, :ci_string, allow_nil?: false
    attribute :bio, :string
    timestamps()
  end

  identities do
    identity :unique_email, [:email]
  end

  relationships do
    has_many :posts, MyApp.Blog.Post
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
```

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "posts"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :body, :string, allow_nil?: false
    attribute :status, :atom do
      constraints one_of: [:draft, :published, :archived]
      default :draft
    end
    attribute :published_at, :utc_datetime_usec
    timestamps()
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    belongs_to :author, MyApp.Blog.Author, allow_nil?: false
    has_many :comments, MyApp.Blog.Comment
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :body, :author_id]

      change fn changeset, _context ->
        title = Ash.Changeset.get_attribute(changeset, :title)
        slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
        Ash.Changeset.change_attribute(changeset, :slug, slug)
      end
    end

    update :update do
      accept [:title, :body]
    end

    update :publish do
      change set_attribute(:status, :published)
      change set_attribute(:published_at, &DateTime.utc_now/0)
    end

    update :archive do
      change set_attribute(:status, :archived)
    end
  end
end
```

Several things to notice. Relationships are declared, not implemented. Ash generates the foreign keys, the preloading logic, the join queries. The `create` action includes a change that derives the slug from the title — this runs automatically on every create.

The `publish` action is a named update that encapsulates a business operation. Calling `Ash.update!(post, :publish)` transitions the post to published status and records the timestamp. The caller does not need to know the implementation details.

## Actions in Depth

Actions are where Ash's declarative nature shines brightest. Let me show you the full spectrum.

### Default Actions

The simplest case. Tell Ash you want standard CRUD:

```elixir
actions do
  defaults [:read, :destroy, create: :*, update: :*]
end
```

The `:*` syntax means "accept all public attributes." You can also list specific attributes: `create: [:name, :email]`.

### Custom Create and Update Actions

Most applications need more than generic CRUD. Actions let you model specific operations:

```elixir
actions do
  create :register do
    accept [:email, :name, :password]

    argument :password_confirmation, :string, allow_nil?: false

    validate confirm(:password, :password_confirmation)

    change fn changeset, _context ->
      password = Ash.Changeset.get_argument(changeset, :password)
      hashed = Bcrypt.hash_pwd_salt(password)
      Ash.Changeset.change_attribute(changeset, :hashed_password, hashed)
    end
  end

  update :change_password do
    accept []

    argument :current_password, :string, allow_nil?: false
    argument :new_password, :string, allow_nil?: false
    argument :new_password_confirmation, :string, allow_nil?: false

    validate confirm(:new_password, :new_password_confirmation)

    change fn changeset, context ->
      # Verify current password, set new one
      record = changeset.data
      current = Ash.Changeset.get_argument(changeset, :current_password)

      if Bcrypt.verify_pass(current, record.hashed_password) do
        new_password = Ash.Changeset.get_argument(changeset, :new_password)
        hashed = Bcrypt.hash_pwd_salt(new_password)
        Ash.Changeset.change_attribute(changeset, :hashed_password, hashed)
      else
        Ash.Changeset.add_error(changeset, field: :current_password, message: "is incorrect")
      end
    end
  end
end
```

Actions accept arguments (ephemeral input that is not persisted), run validations, and apply changes. The changes can be inline functions or reusable modules.

### Read Actions with Filters

Read actions support sophisticated querying:

```elixir
actions do
  read :read do
    primary? true
  end

  read :published do
    filter expr(status == :published)
  end

  read :by_author do
    argument :author_id, :uuid, allow_nil?: false
    filter expr(author_id == ^arg(:author_id))
  end

  read :search do
    argument :query, :string, allow_nil?: false
    filter expr(contains(title, ^arg(:query)) or contains(body, ^arg(:query)))
  end
end
```

Each read action is a named query. `Ash.read!(MyApp.Blog.Post, :published)` returns only published posts. The filters compile to SQL — no loading everything into memory and filtering in Elixir.

### Generic Actions

Sometimes you need actions that do not fit the CRUD model:

```elixir
actions do
  action :send_welcome_email, :boolean do
    argument :user_id, :uuid, allow_nil?: false

    run fn input, _context ->
      user = Ash.get!(MyApp.Accounts.User, input.arguments.user_id)
      MyApp.Mailer.deliver_welcome(user)
      {:ok, true}
    end
  end
end
```

Generic actions can return any type. They participate in authorization, transaction handling, and all other Ash machinery.

## Policies: Declarative Authorization

Authorization logic typically scatters across controllers, context functions, and ad-hoc checks. Ash centralizes it in policies.

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  # ... attributes, relationships, actions ...

  policies do
    # Anyone can read published posts
    policy action_type(:read) do
      authorize_if expr(status == :published)
    end

    # Authors can read their own drafts
    policy action_type(:read) do
      authorize_if expr(author_id == ^actor(:id))
    end

    # Only the author can update their posts
    policy action_type(:update) do
      authorize_if expr(author_id == ^actor(:id))
    end

    # Only the author can delete their posts
    policy action_type(:destroy) do
      authorize_if expr(author_id == ^actor(:id))
    end

    # Only authenticated users can create posts
    policy action_type(:create) do
      authorize_if actor_present()
    end

    # Admins can do anything
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end
  end
end
```

Policies compose with OR semantics within a policy and AND semantics between policies of the same type. The `bypass` block short-circuits evaluation — if the actor is an admin, no further checks run.

The `expr()` macro compiles to database queries when possible. Checking `author_id == ^actor(:id)` adds a WHERE clause rather than loading records and filtering in Elixir. This matters for performance on large datasets.

To use policies, pass the actor when calling actions:

```elixir
# In a Phoenix controller or LiveView
current_user = get_current_user(conn)

# This will only return posts the user is authorized to see
posts = MyApp.Blog.read!(MyApp.Blog.Post, actor: current_user)

# This will raise if the user cannot update this post
Ash.update!(post, :publish, actor: current_user)
```

## When Ash Makes Sense

Ash is not universally appropriate. It excels in specific contexts and adds friction in others.

**Use Ash when:**

You have a complex domain with many resources and relationships. The declarative approach scales better than imperative code as complexity grows. At 5 resources, the overhead may not pay off. At 50 resources with intricate authorization rules, Ash's consistency becomes invaluable.

Your authorization logic is complex. If you have role-based access, resource-level permissions, and field-level visibility rules, Ash policies handle this cleanly. Implementing equivalent logic imperatively requires discipline and invites inconsistency.

You want API consistency. Ash can generate GraphQL and JSON:API endpoints from your resource definitions. If you need multiple API formats from the same domain model, this is a significant win.

You are building a multi-tenant application. Ash has first-class support for multitenancy. Tenant isolation in queries, migrations, and authorization comes built-in.

**Stick with plain Phoenix/Ecto when:**

Your application is small and unlikely to grow. Ash has a learning curve. For a simple CRUD app with 3-5 resources, that curve may never pay off.

You need maximum performance and control. Ash generates efficient queries, but it is an abstraction. If you need hand-tuned SQL for specific hot paths, Ash can feel constraining.

Your team is unfamiliar with declarative patterns. Ash requires thinking differently about application structure. If your team thinks imperatively and your timeline is tight, introducing Ash adds risk.

You are doing something unusual. Ash optimizes for common patterns. If your domain has deeply unconventional semantics — temporal data, event sourcing, exotic storage backends — fighting the framework will cost more than building bespoke.

## Building a Complete Feature

Let me show Ash in action with a complete feature: a comment system with nested replies, moderation, and authorization.

```elixir
defmodule MyApp.Blog.Comment do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "comments"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :body, :string, allow_nil?: false
    attribute :status, :atom do
      constraints one_of: [:pending, :approved, :rejected, :spam]
      default :pending
    end
    timestamps()
  end

  relationships do
    belongs_to :post, MyApp.Blog.Post, allow_nil?: false
    belongs_to :author, MyApp.Blog.Author, allow_nil?: false
    belongs_to :parent, MyApp.Blog.Comment, allow_nil?: true
    has_many :replies, MyApp.Blog.Comment, destination_attribute: :parent_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:body, :post_id, :parent_id]

      change relate_actor(:author)

      # Auto-approve comments from trusted authors
      change fn changeset, context ->
        actor = context.actor
        if actor && actor.trusted do
          Ash.Changeset.change_attribute(changeset, :status, :approved)
        else
          changeset
        end
      end
    end

    update :approve do
      change set_attribute(:status, :approved)
    end

    update :reject do
      change set_attribute(:status, :rejected)
    end

    update :mark_spam do
      change set_attribute(:status, :spam)
    end

    read :approved do
      filter expr(status == :approved)
    end

    read :pending_moderation do
      filter expr(status == :pending)
    end

    read :for_post do
      argument :post_id, :uuid, allow_nil?: false
      filter expr(post_id == ^arg(:post_id) and is_nil(parent_id) and status == :approved)
      prepare build(load: [:replies, :author])
    end
  end

  policies do
    # Anyone can read approved comments
    policy action(:approved) do
      authorize_if always()
    end

    policy action(:for_post) do
      authorize_if always()
    end

    # Authenticated users can create comments
    policy action(:create) do
      authorize_if actor_present()
    end

    # Authors can edit/delete their own comments
    policy action_type([:update, :destroy]) do
      authorize_if expr(author_id == ^actor(:id))
    end

    # Moderators can see pending comments and moderate
    policy action(:pending_moderation) do
      authorize_if actor_attribute_equals(:role, :moderator)
    end

    policy action([:approve, :reject, :mark_spam]) do
      authorize_if actor_attribute_equals(:role, :moderator)
    end

    # Post authors can moderate comments on their posts
    policy action([:approve, :reject, :mark_spam]) do
      authorize_if expr(post.author_id == ^actor(:id))
    end

    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end
  end
end
```

Using this in a Phoenix LiveView:

```elixir
defmodule MyAppWeb.PostLive.Show do
  use MyAppWeb, :live_view

  def mount(%{"id" => post_id}, _session, socket) do
    post = Ash.get!(MyApp.Blog.Post, post_id, load: [:author])
    comments = MyApp.Blog.read!(MyApp.Blog.Comment, :for_post,
      args: %{post_id: post_id},
      actor: socket.assigns.current_user
    )

    {:ok, assign(socket, post: post, comments: comments)}
  end

  def handle_event("submit_comment", %{"body" => body}, socket) do
    case Ash.create(MyApp.Blog.Comment, :create,
      params: %{body: body, post_id: socket.assigns.post.id},
      actor: socket.assigns.current_user
    ) do
      {:ok, comment} ->
        {:noreply, update(socket, :comments, &[comment | &1])}

      {:error, changeset} ->
        {:noreply, assign(socket, error: format_errors(changeset))}
    end
  end

  def handle_event("approve_comment", %{"id" => comment_id}, socket) do
    comment = Ash.get!(MyApp.Blog.Comment, comment_id)

    case Ash.update(comment, :approve, actor: socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply, refresh_comments(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Not authorized")}
    end
  end
end
```

The LiveView code is minimal. It calls Ash actions, passes the actor, and handles results. Authorization is enforced automatically. Validation errors surface through changesets.

## The Tradeoffs

Ash is opinionated software. It makes decisions for you, and those decisions have consequences.

You give up some flexibility. Ash's execution model assumes certain patterns. If your domain genuinely does not fit those patterns, you will fight the framework.

You gain consistency. Every resource works the same way. Every action follows the same lifecycle. New team members can understand one resource and immediately understand all of them.

You add a layer of abstraction. This is neither good nor bad — it depends on your context. Abstractions trade flexibility for leverage. If you need the leverage, the trade is worth it.

You commit to learning a substantial framework. Ash has depth. Mastering it takes weeks, not hours. If you are building something quickly and discarding it, that investment may not pay off.

My recommendation: evaluate Ash when your domain complexity exceeds what feels maintainable with plain Ecto schemas and Phoenix contexts. If you find yourself writing the same authorization checks in multiple places, the same validation logic in multiple contexts, the same query patterns for different resources — Ash may be the systematic solution you need.

Start small. Model one bounded context with Ash. Live with it for a few weeks. If it clicks, expand. If it does not, you have learned something valuable about your domain.

---

**Claims to verify:**
- Ash syntax and API examples should be verified against Ash 3.x documentation (examples written for Ash 3.0+)
- Policy composition semantics (OR within policy, AND between policies) should be confirmed in current Ash.Policy.Authorizer docs
- AshPostgres configuration syntax may vary by version
- `relate_actor/1` change availability and syntax should be verified
- Generic action return types and `run` callback structure should be confirmed against current Ash.Resource.Actions documentation
