%{
title: "N 1 Issues With Ecto And Elixir",
category: "Programming",
tags: ["elixir","functional programming","programming"],
description: "An overview of n 1 problems with elixir and ecto and how to deal with them",
published: true
}
---

<!--An overview of N+1 problems with elixir and Ecto and how to deal with them-->

Your Elixir application is making 1,001 database queries to render a single page. It should be making 2. You probably don't know this yet, because the page loads in 200ms on your development machine with 50 rows in the database. In production, with 10,000 rows, it takes 14 seconds and your users are leaving.

This is the N+1 query problem. It is the most common performance defect in applications that use an ORM or database wrapper, and Ecto applications are not immune. But here is the thing that sets Ecto apart from tools like ActiveRecord or Django's ORM: Ecto makes N+1 queries *visible*. It forces you to be explicit about data loading. The problem is not that Ecto makes it easy to write N+1 queries. The problem is that developers don't recognize the pattern when they write it.

Let's fix that.

## The Schema: A Concrete Example

Every N+1 article needs a concrete domain, so let's use one that maps cleanly to the problem: a content platform with posts, authors, and comments. Here are the schemas:

```elixir
defmodule Blog.Accounts.Author do
  use Ecto.Schema

  schema "authors" do
    field :name, :string
    field :email, :string
    has_many :posts, Blog.Content.Post
    timestamps()
  end
end

defmodule Blog.Content.Post do
  use Ecto.Schema

  schema "posts" do
    field :title, :string
    field :body, :string
    belongs_to :author, Blog.Accounts.Author
    has_many :comments, Blog.Content.Comment
    timestamps()
  end
end

defmodule Blog.Content.Comment do
  use Ecto.Schema

  schema "comments" do
    field :body, :string
    belongs_to :post, Blog.Content.Post
    timestamps()
  end
end
```

Nothing exotic. Three tables, two `has_many` relationships, two `belongs_to` references. This is the kind of schema you build on day one of any Phoenix project. And it is precisely where N+1 queries are born.

## Anatomy of an N+1

Consider a typical controller action that lists posts with their authors:

```elixir
defmodule BlogWeb.PostController do
  use BlogWeb, :controller

  alias Blog.Repo
  alias Blog.Content.Post

  def index(conn, _params) do
    posts = Repo.all(Post)
    render(conn, :index, posts: posts)
  end
end
```

In the template, you iterate over posts and display each author's name:

```elixir
# In your template or LiveView
for post <- @posts do
  post.author.name  # This triggers a query for EACH post
end
```

Except it doesn't work. Ecto raises an `Ecto.Association.NotLoaded` error. Unlike ActiveRecord, Ecto will not silently fire a query behind your back. You have to explicitly load the association. So the developer "fixes" it:

```elixir
def index(conn, _params) do
  posts = Repo.all(Post)
  posts = Enum.map(posts, fn post -> Repo.preload(post, :author) end)
  render(conn, :index, posts: posts)
end
```

This works. It also generates the following SQL:

```sql
-- Query 1: Fetch all posts
SELECT p.id, p.title, p.body, p.author_id FROM posts AS p;

-- Query 2: Fetch author for post 1
SELECT a.id, a.name, a.email FROM authors AS a WHERE a.id = 1;

-- Query 3: Fetch author for post 2
SELECT a.id, a.name, a.email FROM authors AS a WHERE a.id = 2;

-- Query 4: Fetch author for post 3
SELECT a.id, a.name, a.email FROM authors AS a WHERE a.id = 3;

-- ... one query per post
-- Query N+1: Fetch author for post N
SELECT a.id, a.name, a.email FROM authors AS a WHERE a.id = N;
```

For 100 posts, that is 101 database round-trips. For 1,000 posts, it is 1,001. Each round-trip carries network latency, connection pool overhead, and query parsing cost. The database itself could execute a single query in microseconds, but you are paying the per-query tax a thousand times over.

The fix is three lines away. The tragedy is that the developer already knew about `preload` and used it. They just used it wrong.

## The Three Preloading Strategies

Ecto provides three distinct mechanisms for loading associations, each with different SQL generation strategies and performance characteristics. Understanding when to use which is the difference between a fast application and a slow one.

### Strategy 1: `Repo.preload/2` on a Collection

The simplest fix for the N+1 above is to preload the entire collection at once instead of preloading each record individually:

```elixir
def list_posts_with_authors do
  Post
  |> Repo.all()
  |> Repo.preload(:author)
end
```

This generates exactly two queries:

```sql
-- Query 1: Fetch all posts
SELECT p.id, p.title, p.body, p.author_id FROM posts AS p;

-- Query 2: Fetch all relevant authors in one shot
SELECT a.id, a.name, a.email FROM authors AS a WHERE a.id IN (1, 2, 3, ...);
```

Two queries. Always two, regardless of whether you have 10 posts or 10,000. The `IN` clause collects all unique `author_id` values from the first result set and fetches them in a single round-trip.

You can nest preloads for deeper associations:

```elixir
posts = Repo.all(Post) |> Repo.preload([:author, comments: :post])
```

This will generate one query per association level, which is still O(depth) rather than O(N).

### Strategy 2: `Ecto.Query.preload/3` at Query Time

Instead of preloading after the query executes, you can declare preloads as part of the query itself:

```elixir
def list_posts_with_authors do
  Post
  |> preload(:author)
  |> Repo.all()
end
```

The SQL output is identical to `Repo.preload/2` — two separate queries. But the semantics are different. Query-time preloads are composable. You can build them into reusable query functions:

```elixir
defmodule Blog.Content do
  import Ecto.Query

  def list_posts(opts \\ []) do
    Post
    |> maybe_preload_author(opts[:with_author])
    |> maybe_preload_comments(opts[:with_comments])
    |> Repo.all()
  end

  defp maybe_preload_author(query, true), do: preload(query, :author)
  defp maybe_preload_author(query, _), do: query

  defp maybe_preload_comments(query, true), do: preload(query, :comments)
  defp maybe_preload_comments(query, _), do: query
end
```

This pattern lets callers declare exactly what data they need. A list page that only shows titles skips the preload entirely. A detail page that shows author and comments opts in. No over-fetching, no under-fetching.

### Strategy 3: Join-Based Preloading

Both previous strategies generate multiple queries — one for the primary data, one per association. Sometimes you want a single query. Ecto supports this through join-based preloads:

```elixir
def list_posts_with_authors do
  Post
  |> join(:left, [p], a in assoc(p, :author))
  |> preload([p, a], author: a)
  |> Repo.all()
end
```

This generates a single SQL query:

```sql
SELECT p.id, p.title, p.body, p.author_id, a.id, a.name, a.email
FROM posts AS p
LEFT JOIN authors AS a ON a.id = p.author_id;
```

One query. One round-trip. The join happens in the database, which is where it belongs.

The trade-off is data duplication in the result set. If an author has 50 posts, the author's data is repeated 50 times in the wire transfer. For `belongs_to` relationships (many-to-one), this is negligible. For `has_many` relationships with large fanout, the separate-query approach is often better because it avoids the Cartesian product.

Here is the decision framework I use:

| Relationship | Best Strategy | Why |
|---|---|---|
| `belongs_to` (many-to-one) | Join-based preload | Minimal duplication, single round-trip |
| `has_many` (small fanout) | `Ecto.Query.preload` | Avoids Cartesian explosion, 2 queries |
| `has_many` (large fanout) | `Repo.preload` post-query | Separate queries, no result bloat |
| Conditional loading | `Ecto.Query.preload` | Composable query building |

## Detecting N+1 Queries

The best preloading strategy is worthless if you don't know you have a problem. Ecto integrates with Erlang's telemetry system, and you should be using it.

### Ecto's Built-In Logger

In development, Ecto logs every query by default. Your terminal shows output like this:

```
[debug] QUERY OK source="posts" db=1.2ms
SELECT p0."id", p0."title", p0."body", p0."author_id" FROM "posts" AS p0 []

[debug] QUERY OK source="authors" db=0.8ms
SELECT a0."id", a0."name", a0."email" FROM "authors" AS a0 WHERE (a0."id" = $1) [1]

[debug] QUERY OK source="authors" db=0.7ms
SELECT a0."id", a0."name", a0."email" FROM "authors" AS a0 WHERE (a0."id" = $1) [2]
```

When you see the same query template repeated with different parameters, that is your N+1. Train yourself to watch the logs during development. It takes thirty seconds to spot the pattern.

### Custom Telemetry Handlers

For systematic detection, attach a telemetry handler that tracks query frequency per request:

```elixir
defmodule Blog.Telemetry.QueryTracker do
  require Logger

  def setup do
    :telemetry.attach(
      "blog-query-tracker",
      [:blog, :repo, :query],
      &__MODULE__.handle_event/4,
      %{}
    )
  end

  def handle_event([:blog, :repo, :query], measurements, metadata, _config) do
    if measurements.total_time > 50_000_000 do  # 50ms in native units
      Logger.warning(
        "Slow query detected (#{System.convert_time_unit(measurements.total_time, :native, :millisecond)}ms): #{metadata.source}"
      )
    end
  end
end
```

In your `Application.start/2`:

```elixir
def start(_type, _args) do
  Blog.Telemetry.QueryTracker.setup()
  # ... rest of supervision tree
end
```

This gives you runtime visibility. But the real power move is building a development-only plug that counts queries per request and raises a warning when the count exceeds a threshold:

```elixir
defmodule BlogWeb.Plugs.QueryCounter do
  @behaviour Plug
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    Process.put(:query_count, 0)

    :telemetry.attach(
      "request-query-counter-#{inspect(self())}",
      [:blog, :repo, :query],
      fn _event, _measurements, _metadata, _config ->
        Process.put(:query_count, (Process.get(:query_count) || 0) + 1)
      end,
      %{}
    )

    register_before_send(conn, fn conn ->
      count = Process.get(:query_count, 0)
      :telemetry.detach("request-query-counter-#{inspect(self())}")

      if count > 10 do
        require Logger
        Logger.warning("Request to #{conn.request_path} executed #{count} queries")
      end

      conn
    end)
  end
end
```

Add this to your development-only pipeline and you will never ship an N+1 to production without knowing about it first.

## Dataloader: Batched Loading for GraphQL

If you are building a GraphQL API with Absinthe, the N+1 problem takes on a different shape. In REST, you control exactly which associations to load in the controller. In GraphQL, the client controls the query shape. A client can request posts with authors with posts with comments, and your resolver tree has no way to predict the nesting depth at compile time.

This is where [Dataloader](https://hex.pm/packages/dataloader) earns its place. Dataloader batches association loads across resolver invocations within a single request, eliminating N+1 queries without requiring the resolver author to think about preloading.

First, define a data source:

```elixir
defmodule Blog.Content.DataSource do
  def data do
    Dataloader.Ecto.new(Blog.Repo, query: &query/2)
  end

  def query(queryable, _params) do
    queryable
  end
end
```

Configure Dataloader in your Absinthe schema:

```elixir
defmodule BlogWeb.Schema do
  use Absinthe.Schema
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(Blog.Content, Blog.Content.DataSource.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end

  object :post do
    field :id, :id
    field :title, :string
    field :author, :author, resolve: dataloader(Blog.Content)
    field :comments, list_of(:comment), resolve: dataloader(Blog.Content)
  end

  # ... rest of schema
end
```

When a GraphQL query requests 50 posts with their authors, Dataloader does not fire 50 author queries. It collects all requested author IDs across all resolver invocations, then issues a single `WHERE id IN (...)` query. The batching happens automatically.

The performance difference is stark. A nested GraphQL query like this:

```graphql
{
  posts(limit: 100) {
    title
    author { name }
    comments { body }
  }
}
```

Without Dataloader: 1 query for posts + 100 queries for authors + 100 queries for comments = 201 queries. With Dataloader: 1 query for posts + 1 batched query for authors + 1 batched query for comments = 3 queries.

That is a 67x reduction in database round-trips. At production scale, this is the difference between a 50ms response and a 3-second timeout.

## The Performance Math

Let's put concrete numbers on this. Assume a PostgreSQL database with an average query overhead of 0.5ms per round-trip (network + parsing + planning) and 0.1ms of actual execution time for a simple primary key lookup.

| Posts | N+1 Queries | Total Time (N+1) | Preloaded Queries | Total Time (Preload) |
|---|---|---|---|---|
| 10 | 11 | ~6.6ms | 2 | ~1.2ms |
| 100 | 101 | ~60.6ms | 2 | ~1.2ms |
| 1,000 | 1,001 | ~600.6ms | 2 | ~2.0ms |
| 10,000 | 10,001 | ~6,000ms | 2 | ~8.0ms |

The N+1 cost scales linearly with dataset size. The preloaded cost barely moves. At 10,000 records, you are looking at 6 seconds versus 8 milliseconds. Three orders of magnitude.

And this is the optimistic scenario — a single association on a local database. Add network latency to a cloud-hosted database, add a second association, and the numbers get worse fast.

## When "Just Preload Everything" Goes Wrong

I've seen teams overcorrect. They encounter an N+1, panic, and add preloads to every query in the application. This creates a different problem: over-fetching.

```elixir
# Don't do this
def list_posts do
  Post
  |> preload([:author, :comments, comments: :author])
  |> Repo.all()
end
```

If the list page only displays post titles, you are loading authors and comments for no reason. Every preload adds a query. Every query returns data that gets deserialized into Elixir structs, consuming memory and CPU time.

The discipline is to load exactly what you need, where you need it. This is where Ecto's explicitness is a feature. ActiveRecord's lazy loading hides the cost. Ecto's explicit loading forces you to declare your data requirements up front. Embrace that.

Build your context functions with configurable preloads:

```elixir
defmodule Blog.Content do
  import Ecto.Query

  def list_posts(preloads \\ []) do
    Post
    |> preload(^preloads)
    |> Repo.all()
  end
end

# Controller for list page — no preloads needed
posts = Blog.Content.list_posts()

# Controller for detail page — load everything
post = Blog.Content.get_post!(id, [:author, :comments])
```

The `^` pin operator in `preload(^preloads)` interpolates a runtime list of associations into the query. This gives the caller full control without duplicating query logic.

## Schema Design Considerations

Some N+1 patterns are symptoms of a schema that fights against your access patterns. A few design considerations worth thinking about:

**Denormalize read-heavy fields.** If every post list page shows the author's name, consider adding an `author_name` field directly to the `posts` table. Yes, this introduces data redundancy. But it eliminates a join entirely. Use Ecto's `prepare_changes/1` or database triggers to keep it in sync.

**Use database views for complex aggregations.** If you frequently need post count per author, or average comment length per post, create a database view and map an Ecto schema to it. This moves the computation to the database where it belongs.

**Index your foreign keys.** This sounds obvious, but I have seen production databases where `posts.author_id` had no index. The `IN` clause that preloading generates will perform a sequential scan on an unindexed column. Always verify your indexes:

```elixir
# In a migration
create index(:posts, [:author_id])
create index(:comments, [:post_id])
```

**Consider composite indexes for filtered preloads.** If you frequently query `comments` filtered by `inserted_at`, a composite index on `[:post_id, :inserted_at]` lets the database satisfy both the foreign key lookup and the time filter from a single index scan.

## The Discipline of Explicit Loading

The N+1 problem is fundamentally a problem of invisible costs. ORMs that lazy-load associations hide the query count from the developer. The code looks clean. The performance is terrible.

Ecto took a different path. It refuses to load associations you did not ask for. This means you see `Ecto.Association.NotLoaded` structs instead of silently degraded performance. It means you have to think about your data access patterns before writing the template. It means the N+1 problem, when it occurs, is always a conscious mistake rather than an accidental one.

The tools are straightforward: `Repo.preload/2` for post-query loading, `Ecto.Query.preload/3` for composable query-time loading, join-based preloads for single-query performance, and Dataloader for GraphQL contexts where the query shape is client-driven. Pick the right tool for the context and your database will thank you.

Every query should be intentional. Every association load should be deliberate. This is not a limitation of Ecto. It is the entire point.

---

*Claims to verify with current data: Dataloader API surface may have evolved since your version of the library — check the latest [Dataloader hexdocs](https://hexdocs.pm/dataloader). Performance figures are order-of-magnitude estimates based on typical PostgreSQL latency profiles; benchmark against your own infrastructure for production planning. Telemetry event names should be verified against your Ecto version, as the prefix depends on your repo's `telemetry_prefix` configuration.*