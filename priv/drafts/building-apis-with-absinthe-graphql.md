%{
title: "Building APIs with Absinthe GraphQL",
category: "Programming",
tags: ["elixir", "graphql", "absinthe", "api"],
description: "Schema design, dataloader, subscriptions, and authentication patterns",
published: false
}
---

REST has served us well for two decades. It is battle-tested, widely understood, and good enough for most applications. But "good enough" has a ceiling, and modern client applications are pressing against it.

The problem is structural. REST endpoints return fixed data shapes. Clients either over-fetch — pulling down entire user objects when they need only names — or under-fetch, triggering waterfalls of sequential requests to assemble a single view. Mobile applications on constrained networks feel this pain acutely. So do frontend teams tired of lobbying backend developers for yet another custom endpoint.

GraphQL addresses this mismatch by inverting the control. Clients declare exactly what they need. The server fulfills that contract. No more, no less.

In the Elixir ecosystem, Absinthe is the definitive GraphQL implementation. It is not a port or a wrapper around a JavaScript library. It is GraphQL reimagined through the lens of functional programming, pattern matching, and the BEAM's concurrency model. The result is an API layer that handles complex queries with the same elegance Elixir brings to everything else.

---

## Why Absinthe Wins

Several GraphQL implementations exist across languages. Absinthe distinguishes itself in ways that matter for production systems.

**Native Elixir, Native Idioms.** Absinthe schemas are defined using Elixir macros. Types, fields, and resolvers compose naturally with the rest of your codebase. There is no context-switching between a schema definition language and your application code — it is Elixir all the way down.

**First-Class Subscriptions.** Real-time features are not an afterthought bolted on via polling. Absinthe integrates directly with Phoenix Channels, leveraging the BEAM's lightweight processes to maintain thousands of concurrent subscriptions without breaking a sweat. Each subscription is an isolated process. One misbehaving client cannot poison others.

**Dataloader for N+1 Prevention.** The N+1 query problem has killed more GraphQL implementations than any other issue. Absinthe's Dataloader library batches database calls automatically, collapsing hundreds of queries into a handful. This is not optional — it is essential for any GraphQL API beyond toy scale.

**Middleware Architecture.** Authentication, authorization, logging, error handling — these cross-cutting concerns slot cleanly into Absinthe's middleware pipeline. You write the logic once and apply it declaratively across your schema.

---

## Schema Design That Scales

A well-designed schema is the foundation of a maintainable GraphQL API. Get this wrong, and you will spend months refactoring. Get it right, and the schema becomes living documentation that clients can explore.

### Defining Types

Start with your core domain objects. Each type maps to a concept in your business domain, not necessarily to a database table.

```elixir
defmodule MyApp.Schema.Types.User do
  use Absinthe.Schema.Notation

  object :user do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string
    field :role, non_null(:user_role)
    field :inserted_at, non_null(:datetime)

    field :posts, list_of(:post) do
      resolve &MyApp.Resolvers.Content.list_user_posts/3
    end
  end

  enum :user_role do
    value :admin, description: "Full system access"
    value :editor, description: "Can create and edit content"
    value :viewer, description: "Read-only access"
  end
end
```

Notice the explicit resolver for the `posts` field. This is not fetched eagerly with the user — it is resolved only when the client requests it. This lazy resolution is fundamental to GraphQL's efficiency.

### Queries and Mutations

Separate your schema into logical modules. The root schema composes them.

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema

  import_types MyApp.Schema.Types.User
  import_types MyApp.Schema.Types.Post
  import_types MyApp.Schema.Types.Comment

  query do
    @desc "Fetch a user by ID"
    field :user, :user do
      arg :id, non_null(:id)
      resolve &MyApp.Resolvers.Accounts.get_user/3
    end

    @desc "List all published posts with optional filters"
    field :posts, list_of(:post) do
      arg :limit, :integer, default_value: 20
      arg :offset, :integer, default_value: 0
      arg :status, :post_status
      resolve &MyApp.Resolvers.Content.list_posts/3
    end
  end

  mutation do
    @desc "Create a new post"
    field :create_post, :post do
      arg :input, non_null(:create_post_input)
      middleware MyApp.Middleware.Authenticate
      middleware MyApp.Middleware.Authorize, :create_post
      resolve &MyApp.Resolvers.Content.create_post/3
    end

    @desc "Update an existing post"
    field :update_post, :post do
      arg :id, non_null(:id)
      arg :input, non_null(:update_post_input)
      middleware MyApp.Middleware.Authenticate
      resolve &MyApp.Resolvers.Content.update_post/3
    end
  end
end
```

Input types keep mutations organized and self-documenting.

```elixir
input_object :create_post_input do
  field :title, non_null(:string)
  field :body, non_null(:string)
  field :status, :post_status, default_value: :draft
  field :tag_ids, list_of(:id)
end
```

---

## Taming N+1 with Dataloader

Here is the scenario that breaks naive GraphQL implementations. A client requests a list of posts, each with its author. Without batching, you execute one query for posts, then N additional queries for authors — one per post. At scale, this is catastrophic.

Dataloader solves this by collecting all the keys needed during resolution, then executing a single batched query. The setup requires a data source and integration into your schema.

```elixir
defmodule MyApp.Dataloader.Source do
  def data do
    Dataloader.Ecto.new(MyApp.Repo, query: &query/2)
  end

  defp query(queryable, _params) do
    queryable
  end
end
```

Wire it into your schema's context.

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(:db, MyApp.Dataloader.Source.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end

  # ... rest of schema
end
```

Now your resolvers can batch transparently.

```elixir
object :post do
  field :id, non_null(:id)
  field :title, non_null(:string)
  field :body, non_null(:string)

  field :author, non_null(:user) do
    resolve fn post, _args, %{context: %{loader: loader}} ->
      loader
      |> Dataloader.load(:db, :author, post)
      |> on_load(fn loader ->
        {:ok, Dataloader.get(loader, :db, :author, post)}
      end)
    end
  end

  field :comments, list_of(:comment) do
    resolve fn post, _args, %{context: %{loader: loader}} ->
      loader
      |> Dataloader.load(:db, :comments, post)
      |> on_load(fn loader ->
        {:ok, Dataloader.get(loader, :db, :comments, post)}
      end)
    end
  end
end
```

For cleaner code, use the `dataloader/1` helper.

```elixir
import Absinthe.Resolution.Helpers, only: [dataloader: 1]

object :post do
  field :author, non_null(:user), resolve: dataloader(:db)
  field :comments, list_of(:comment), resolve: dataloader(:db)
end
```

Dataloader batches all author and comment lookups into two queries, regardless of how many posts are in the result set. This is the difference between an API that works in development and one that survives production traffic.

---

## Real-Time with Subscriptions

Phoenix Channels provide the WebSocket infrastructure. Absinthe subscriptions provide the GraphQL semantics. Together, they enable real-time features with minimal ceremony.

Define subscription fields in your schema.

```elixir
subscription do
  @desc "Subscribe to new comments on a post"
  field :comment_added, :comment do
    arg :post_id, non_null(:id)

    config fn args, _context ->
      {:ok, topic: "post:#{args.post_id}:comments"}
    end

    trigger :create_comment,
      topic: fn comment ->
        "post:#{comment.post_id}:comments"
      end
  end

  @desc "Subscribe to post updates"
  field :post_updated, :post do
    arg :id, non_null(:id)

    config fn args, _context ->
      {:ok, topic: "post:#{args.id}"}
    end
  end
end
```

Configure your socket to handle Absinthe subscriptions.

```elixir
defmodule MyAppWeb.UserSocket do
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket, schema: MyApp.Schema

  def connect(%{"token" => token}, socket, _connect_info) do
    case MyApp.Accounts.verify_token(token) do
      {:ok, user} ->
        socket = Absinthe.Phoenix.Socket.put_options(socket,
          context: %{current_user: user}
        )
        {:ok, socket}
      {:error, _} ->
        :error
    end
  end

  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
```

Trigger subscription events when data changes.

```elixir
defmodule MyApp.Resolvers.Content do
  def create_comment(_parent, %{input: input}, %{context: %{current_user: user}}) do
    case MyApp.Content.create_comment(input, user) do
      {:ok, comment} ->
        Absinthe.Subscription.publish(
          MyAppWeb.Endpoint,
          comment,
          comment_added: "post:#{comment.post_id}:comments"
        )
        {:ok, comment}
      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  end
end
```

Each subscription runs in its own process. The BEAM handles thousands concurrently without the thread-pool contention you would fight in other runtimes.

---

## Authentication and Authorization

Security is not optional. Absinthe's middleware system makes it composable.

### Authentication Middleware

Verify the user exists in the context before allowing resolution to proceed.

```elixir
defmodule MyApp.Middleware.Authenticate do
  @behaviour Absinthe.Middleware

  def call(resolution, _config) do
    case resolution.context do
      %{current_user: %{}} ->
        resolution
      _ ->
        resolution
        |> Absinthe.Resolution.put_result({:error, "Authentication required"})
    end
  end
end
```

### Authorization Middleware

Check permissions against the authenticated user.

```elixir
defmodule MyApp.Middleware.Authorize do
  @behaviour Absinthe.Middleware

  def call(resolution, permission) do
    user = resolution.context[:current_user]

    if MyApp.Accounts.can?(user, permission) do
      resolution
    else
      resolution
      |> Absinthe.Resolution.put_result({:error, "Unauthorized"})
    end
  end
end
```

Apply middleware at the field level for granular control.

```elixir
field :delete_user, :user do
  arg :id, non_null(:id)
  middleware MyApp.Middleware.Authenticate
  middleware MyApp.Middleware.Authorize, :delete_user
  resolve &MyApp.Resolvers.Accounts.delete_user/3
end
```

For schema-wide defaults, use `middleware/3` callbacks.

```elixir
def middleware(middleware, _field, %{identifier: :mutation}) do
  [MyApp.Middleware.Authenticate | middleware]
end

def middleware(middleware, _field, _object), do: middleware
```

Every mutation now requires authentication by default. Explicit is better than implicit, but sensible defaults reduce boilerplate.

---

## Structured Error Handling

GraphQL errors should be machine-parseable, not just human-readable. Use error extensions to provide structured metadata.

```elixir
defmodule MyApp.ErrorHelpers do
  def format_changeset_errors(changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)

    %{
      message: "Validation failed",
      extensions: %{
        code: "VALIDATION_ERROR",
        fields: errors
      }
    }
  end
end
```

Create custom error tuples that Absinthe can serialize.

```elixir
defmodule MyApp.Middleware.ErrorHandler do
  @behaviour Absinthe.Middleware

  def call(resolution, _config) do
    %{resolution |
      errors: Enum.map(resolution.errors, &transform_error/1)
    }
  end

  defp transform_error(%Ecto.Changeset{} = changeset) do
    MyApp.ErrorHelpers.format_changeset_errors(changeset)
  end

  defp transform_error({:error, :not_found}) do
    %{message: "Resource not found", extensions: %{code: "NOT_FOUND"}}
  end

  defp transform_error({:error, :unauthorized}) do
    %{message: "Not authorized", extensions: %{code: "UNAUTHORIZED"}}
  end

  defp transform_error(error), do: error
end
```

Clients receive consistent, actionable error responses.

```json
{
  "errors": [
    {
      "message": "Validation failed",
      "extensions": {
        "code": "VALIDATION_ERROR",
        "fields": {
          "email": ["has already been taken"]
        }
      }
    }
  ]
}
```

---

## Testing GraphQL APIs

Absinthe integrates cleanly with ExUnit. Test at the resolution level for unit tests, at the HTTP level for integration tests.

### Unit Testing Resolvers

```elixir
defmodule MyApp.Resolvers.AccountsTest do
  use MyApp.DataCase

  alias MyApp.Resolvers.Accounts

  describe "get_user/3" do
    test "returns user when found" do
      user = insert(:user)
      args = %{id: user.id}
      context = %{current_user: user}

      assert {:ok, returned_user} = Accounts.get_user(nil, args, %{context: context})
      assert returned_user.id == user.id
    end

    test "returns error when not found" do
      args = %{id: Ecto.UUID.generate()}
      context = %{current_user: insert(:user)}

      assert {:error, "User not found"} = Accounts.get_user(nil, args, %{context: context})
    end
  end
end
```

### Integration Testing with Absinthe

```elixir
defmodule MyAppWeb.Schema.QueryTest do
  use MyAppWeb.ConnCase

  @user_query """
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      email
      name
      posts {
        title
      }
    }
  }
  """

  describe "user query" do
    test "returns user with posts", %{conn: conn} do
      user = insert(:user)
      post = insert(:post, author: user)

      conn =
        conn
        |> put_auth_header(user)
        |> post("/api/graphql", %{
          query: @user_query,
          variables: %{id: user.id}
        })

      assert %{
        "data" => %{
          "user" => %{
            "id" => id,
            "email" => email,
            "posts" => [%{"title" => title}]
          }
        }
      } = json_response(conn, 200)

      assert id == to_string(user.id)
      assert email == user.email
      assert title == post.title
    end

    test "returns error for missing user", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_auth_header(user)
        |> post("/api/graphql", %{
          query: @user_query,
          variables: %{id: Ecto.UUID.generate()}
        })

      assert %{"errors" => [%{"message" => "User not found"}]} = json_response(conn, 200)
    end
  end
end
```

Test subscriptions using Absinthe's test helpers.

```elixir
defmodule MyAppWeb.Schema.SubscriptionTest do
  use MyAppWeb.SubscriptionCase

  @comment_subscription """
  subscription CommentAdded($postId: ID!) {
    commentAdded(postId: $postId) {
      id
      body
    }
  }
  """

  test "receives new comments on subscribed post" do
    user = insert(:user)
    post = insert(:post)

    {:ok, socket} = connect(MyAppWeb.UserSocket, %{"token" => generate_token(user)})
    ref = push_doc(socket, @comment_subscription, variables: %{postId: post.id})

    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    comment = insert(:comment, post: post, author: user)
    Absinthe.Subscription.publish(MyAppWeb.Endpoint, comment,
      comment_added: "post:#{post.id}:comments"
    )

    assert_push "subscription:data", %{
      subscriptionId: ^subscription_id,
      result: %{data: %{"commentAdded" => %{"id" => _, "body" => body}}}
    }

    assert body == comment.body
  end
end
```

---

## Closing Thoughts

Absinthe is not just a GraphQL library. It is a demonstration of what happens when a protocol is implemented idiomatically rather than ported mechanically. Pattern matching replaces conditional sprawl. Middleware pipelines replace scattered cross-cutting concerns. The BEAM's process model makes subscriptions a natural extension rather than an architectural afterthought.

The patterns outlined here — Dataloader for batching, middleware for auth, structured errors for clients — are not suggestions. They are requirements for any GraphQL API that will face real users and real load. Skip them at your own peril.

GraphQL shifts power to the client. Absinthe ensures the server can handle that shift gracefully.

---

**Claims to verify with current data:**
- Absinthe version compatibility and latest features (check hex.pm for current stable release)
- Dataloader syntax may have evolved — verify against current documentation
- Phoenix Channel integration specifics for your Phoenix version
- Subscription configuration may require additional PubSub setup depending on deployment topology
