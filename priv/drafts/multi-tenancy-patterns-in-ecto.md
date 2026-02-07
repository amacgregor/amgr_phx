%{
title: "Multi-Tenancy Patterns in Ecto",
category: "Programming",
tags: ["elixir", "ecto", "saas", "multi-tenancy"],
description: "Schema-based vs row-based multi-tenancy and query scoping strategies",
published: false
}
---

Multi-tenancy is where SaaS applications go to die or thrive. Get it wrong, and you'll spend years untangling data leaks, performance cliffs, and migration nightmares. Get it right, and you'll have a foundation that scales from your first paying customer to your ten-thousandth without architectural rewrites.

Ecto, Elixir's database wrapper, provides surprisingly elegant primitives for building multi-tenant systems. But the documentation doesn't tell you which pattern to choose or why. That's what we're here to fix.

## The Three Architectures

Multi-tenancy implementations cluster around three fundamental approaches. Each trades off isolation, complexity, and operational overhead differently.

**Database-per-tenant** gives you the strongest isolation. Each customer gets their own PostgreSQL database. Schema changes require coordinated migrations across potentially thousands of databases. Connection pooling becomes a distributed systems problem. This approach makes sense when you have dozens of large enterprise customers with strict compliance requirements. It rarely makes sense for anything else.

**Schema-per-tenant** uses PostgreSQL's schema feature to namespace tables. One database, many schemas. Each tenant's tables live in their own namespace — `tenant_acme.users`, `tenant_globex.users`. You get strong isolation without the operational complexity of multiple databases. Migrations run once and apply to a template schema, then get cloned to tenant schemas. This is the sweet spot for many B2B SaaS applications.

**Row-level tenancy** keeps everything in shared tables with a `tenant_id` column on every row. Simplest to implement, easiest to query across tenants for analytics, but requires vigilant query scoping. One missed `WHERE` clause and you've got a data breach. This works well for applications with many small tenants and limited isolation requirements.

Let me show you how to implement each in Ecto.

## Row-Based Tenancy: The Disciplined Approach

Row-level tenancy is straightforward in principle. Every table gets a `tenant_id` column. Every query includes a tenant filter. The challenge is making "every query" actually mean every query.

Here's a basic schema:

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema

  schema "users" do
    field :email, :string
    field :name, :string
    field :tenant_id, :id

    timestamps()
  end
end
```

The naive approach scatters tenant filtering throughout your codebase:

```elixir
def list_users(tenant_id) do
  User
  |> where(tenant_id: ^tenant_id)
  |> Repo.all()
end
```

This works until someone forgets the filter. And someone will forget.

A better pattern uses composable query functions:

```elixir
defmodule MyApp.Query do
  import Ecto.Query

  def for_tenant(query, tenant_id) do
    where(query, [r], r.tenant_id == ^tenant_id)
  end
end

# Usage
User
|> Query.for_tenant(current_tenant_id)
|> where([u], u.active == true)
|> Repo.all()
```

Still requires discipline. Still fails silently when you forget. We need something that fails loudly.

### The prepare_query Callback

Ecto 3.0 introduced `prepare_query`, a callback that intercepts every query before execution. This is where row-level tenancy gets interesting.

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  require Ecto.Query

  @impl true
  def prepare_query(_operation, query, opts) do
    cond do
      opts[:skip_tenant_id] || opts[:schema_migration] ->
        {query, opts}

      tenant_id = opts[:tenant_id] ->
        {Ecto.Query.where(query, tenant_id: ^tenant_id), opts}

      true ->
        raise "expected tenant_id or skip_tenant_id to be set"
    end
  end
end
```

Now every query must explicitly declare its tenant context:

```elixir
# This works
Repo.all(User, tenant_id: current_tenant.id)

# This also works - for admin queries that span tenants
Repo.all(User, skip_tenant_id: true)

# This raises an error - no silent failures
Repo.all(User)
```

The beauty here is defense in depth. A developer can't accidentally forget tenant scoping. The system demands explicit intent.

You'll want to thread the tenant through your application context. Phoenix's `Plug.Conn` assigns work well:

```elixir
defmodule MyAppWeb.TenantPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_tenant_from_request(conn) do
      {:ok, tenant} ->
        assign(conn, :current_tenant, tenant)

      :error ->
        conn
        |> put_status(:not_found)
        |> halt()
    end
  end

  defp get_tenant_from_request(conn) do
    # Extract from subdomain, header, or path
    # Implementation depends on your routing strategy
  end
end
```

Then in your context modules:

```elixir
defmodule MyApp.Accounts do
  alias MyApp.Repo
  alias MyApp.Accounts.User

  def list_users(%{id: tenant_id}) do
    Repo.all(User, tenant_id: tenant_id)
  end

  def get_user!(tenant, id) do
    Repo.get!(User, id, tenant_id: tenant.id)
  end
end
```

## Schema-Based Tenancy: PostgreSQL Namespaces

PostgreSQL schemas provide namespace isolation at the database level. Each tenant gets their own set of tables, completely invisible to queries in other schemas.

The key mechanism is Ecto's prefix option:

```elixir
# Query tenant_acme's users table
Repo.all(User, prefix: "tenant_acme")

# Insert into tenant_globex's users table
Repo.insert(%User{email: "new@example.com"}, prefix: "tenant_globex")
```

Setting up a new tenant requires creating the schema and running migrations:

```elixir
defmodule MyApp.Tenants do
  alias MyApp.Repo

  def provision_tenant(tenant_slug) do
    prefix = "tenant_#{tenant_slug}"

    # Create the PostgreSQL schema
    Repo.query!("CREATE SCHEMA IF NOT EXISTS #{prefix}")

    # Run migrations for this tenant
    Ecto.Migrator.run(
      Repo,
      migrations_path(),
      :up,
      all: true,
      prefix: prefix
    )

    {:ok, prefix}
  end

  defp migrations_path do
    Application.app_dir(:my_app, "priv/repo/migrations")
  end
end
```

For automatic prefix injection, combine `prepare_query` with `default_options`:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def default_options(_operation) do
    [prefix: get_tenant_prefix()]
  end

  defp get_tenant_prefix do
    case Process.get(:current_tenant_prefix) do
      nil -> "public"
      prefix -> prefix
    end
  end
end
```

Set the prefix at the request boundary:

```elixir
defmodule MyAppWeb.TenantPlug do
  import Plug.Conn

  def call(conn, _opts) do
    tenant = get_tenant_from_subdomain(conn)
    prefix = "tenant_#{tenant.slug}"

    Process.put(:current_tenant_prefix, prefix)
    assign(conn, :current_tenant, tenant)
  end
end
```

The process dictionary approach has trade-offs. It's implicit state, which functional programmers rightly distrust. But the alternative — threading prefix through every function call — creates significant boilerplate. For web requests with clear boundaries, the process dictionary works well. For background jobs, you'll need to explicitly set the prefix when the job starts.

### Handling Cross-Tenant Operations

Sometimes you need to query across tenants — aggregate analytics, admin dashboards, billing reconciliation. Schema-based tenancy makes this harder than row-level.

One pattern uses a dedicated connection that targets the public schema:

```elixir
defmodule MyApp.AdminRepo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  # No default prefix - queries hit public schema
end
```

For aggregations, you can query across schemas with explicit prefixes:

```elixir
def total_users_across_tenants(tenant_slugs) do
  tenant_slugs
  |> Enum.map(fn slug ->
    prefix = "tenant_#{slug}"
    Repo.aggregate(User, :count, prefix: prefix)
  end)
  |> Enum.sum()
end
```

This doesn't scale for complex analytics. At that point, you want an ETL pipeline that materializes cross-tenant data into an analytics database.

## Connection Pooling Strategies

Multi-tenant applications stress connection pools in ways single-tenant apps don't. The strategies differ by tenancy model, and getting this wrong manifests as mysterious timeouts under load.

For row-level tenancy, pooling is straightforward. All tenants share the same pool. Size it based on your total concurrent database operations, not tenant count. A typical starting point is 10-20 connections per Erlang scheduler, which on a 4-core machine gives you 40-80 connections. Monitor checkout times and queue depth to tune from there.

Schema-based tenancy also uses a shared pool, but PostgreSQL needs to issue a `SET search_path` command when switching tenants. Ecto handles this automatically when you use the prefix option, but there's overhead. Each query with a different prefix requires setting the search path. In practice, this adds 1-2ms per query if you're constantly switching contexts. The mitigation is to batch operations per tenant when possible:

```elixir
def process_tenant_batch(tenant, operations) do
  # All operations run with the same prefix, minimizing context switches
  prefix = "tenant_#{tenant.slug}"

  Enum.map(operations, fn op ->
    execute_operation(op, prefix: prefix)
  end)
end
```

Database-per-tenant is where things get interesting. A naive approach creates a connection pool per tenant. With a thousand tenants and a pool size of 10, you need 10,000 database connections. PostgreSQL's default `max_connections` is 100. Even with tuning, you'll hit memory limits long before you hit connection limits — each PostgreSQL connection consumes roughly 5-10MB of RAM.

The solution is dynamic pools or connection proxies like PgBouncer:

```elixir
defmodule MyApp.TenantRepo do
  def get_repo(tenant) do
    # Check if we have a pool for this tenant
    case Registry.lookup(MyApp.RepoRegistry, tenant.id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        start_tenant_pool(tenant)
    end
  end

  defp start_tenant_pool(tenant) do
    config = [
      database: "myapp_#{tenant.slug}",
      username: tenant.db_username,
      password: tenant.db_password,
      hostname: tenant.db_host,
      pool_size: 5
    ]

    DynamicSupervisor.start_child(
      MyApp.RepoSupervisor,
      {MyApp.DynamicRepo, config}
    )
  end
end
```

This approach adds latency for the first request to a cold tenant. Consider pre-warming pools for your most active tenants and implementing pool eviction for dormant ones:

```elixir
defmodule MyApp.TenantPoolManager do
  use GenServer

  @idle_timeout :timer.minutes(30)

  def init(_) do
    schedule_cleanup()
    {:ok, %{last_access: %{}}}
  end

  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - @idle_timeout

    state.last_access
    |> Enum.filter(fn {_tenant_id, last_access} -> last_access < cutoff end)
    |> Enum.each(fn {tenant_id, _} -> terminate_pool(tenant_id) end)

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(5))
  end
end
```

The key insight with connection pooling in multi-tenant systems is that your pool configuration becomes a function of your tenant distribution. If 10% of tenants generate 90% of traffic — which is common — optimize for that hot set and let the long tail pay the cold-start penalty.

## Testing Multi-Tenant Code

Testing multi-tenant applications requires careful attention to isolation. The Ecto sandbox that makes concurrent testing possible can also hide tenancy bugs.

For row-level tenancy, create explicit tenant fixtures:

```elixir
defmodule MyApp.DataCase do
  use ExUnit.CaseTemplate

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    tenant = MyApp.TenantsFixtures.tenant_fixture()
    {:ok, tenant: tenant}
  end
end

defmodule MyApp.AccountsTest do
  use MyApp.DataCase

  describe "list_users/1" do
    test "returns only users for the given tenant", %{tenant: tenant} do
      other_tenant = MyApp.TenantsFixtures.tenant_fixture()

      user = user_fixture(tenant_id: tenant.id)
      _other_user = user_fixture(tenant_id: other_tenant.id)

      assert Accounts.list_users(tenant) == [user]
    end
  end
end
```

For schema-based tenancy, you need to create and tear down schemas:

```elixir
defmodule MyApp.SchemaCase do
  use ExUnit.CaseTemplate

  setup do
    prefix = "test_tenant_#{System.unique_integer([:positive])}"

    Repo.query!("CREATE SCHEMA #{prefix}")

    Ecto.Migrator.run(Repo, migrations_path(), :up, all: true, prefix: prefix)

    on_exit(fn ->
      Repo.query!("DROP SCHEMA #{prefix} CASCADE")
    end)

    {:ok, prefix: prefix}
  end
end
```

The critical test for any multi-tenant system verifies isolation:

```elixir
test "tenant A cannot access tenant B data", %{tenant: tenant_a} do
  tenant_b = tenant_fixture()

  # Create data for tenant B
  secret_user = user_fixture(tenant_id: tenant_b.id, email: "secret@b.com")

  # Attempt to access from tenant A context
  result = Repo.all(User, tenant_id: tenant_a.id)

  refute Enum.any?(result, fn u -> u.id == secret_user.id end)
end
```

Run this test. Run it often. Run it in CI with a flag that fails the build if it ever passes incorrectly.

### Background Jobs and Async Contexts

Testing gets trickier when you have background jobs. The process dictionary trick that works for web requests fails silently in Oban or other job processors because you're in a different process.

The solution is explicit tenant context in job args:

```elixir
defmodule MyApp.Workers.SendReport do
  use Oban.Worker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "report_id" => report_id}}) do
    # Explicitly set tenant context for this job
    tenant = Repo.get!(Tenant, tenant_id, skip_tenant_id: true)
    Process.put(:current_tenant_prefix, "tenant_#{tenant.slug}")

    # Now all queries in this process use the correct tenant
    generate_and_send_report(report_id)
  end
end

# Enqueuing always includes tenant context
def schedule_report(tenant, report) do
  %{tenant_id: tenant.id, report_id: report.id}
  |> MyApp.Workers.SendReport.new()
  |> Oban.insert()
end
```

Test this flow specifically. It's where tenant leakage bugs hide.

## Choosing Your Pattern

The decision matrix is clearer than most architectural choices:

**Choose row-level tenancy when:**
- You have many small tenants (hundreds to millions)
- Cross-tenant analytics are a core feature
- Tenants have similar data volumes
- Regulatory requirements don't mandate physical isolation
- You want the simplest operational model

**Choose schema-based tenancy when:**
- You have moderate tenant counts (dozens to thousands)
- Tenants have significantly different data volumes
- You need stronger isolation without separate databases
- Your team is comfortable with PostgreSQL schemas
- You want per-tenant backup and restore capabilities

**Choose database-per-tenant when:**
- Regulatory or contractual requirements mandate physical isolation
- You have a small number of large enterprise customers
- Each tenant might need different database configurations
- You're willing to invest in sophisticated deployment automation

For most SaaS applications starting out, row-level tenancy with aggressive `prepare_query` enforcement is the right call. It's the simplest to implement, easiest to reason about, and doesn't foreclose future migration to schema-based if you need stronger isolation later.

The migration path from row-level to schema-based is well-trodden. The reverse is painful.

### A Note on Hybrid Approaches

Some systems use both patterns. Core transactional data lives in tenant schemas for isolation, while shared reference data (countries, currencies, product catalogs) lives in a public schema accessible to all tenants. This works, but it requires discipline about which data goes where.

```elixir
defmodule MyApp.Catalog.Product do
  use Ecto.Schema

  # Products are shared, queried from public schema
  @schema_prefix "public"

  schema "products" do
    field :sku, :string
    field :name, :string
    timestamps()
  end
end

defmodule MyApp.Orders.Order do
  use Ecto.Schema

  # Orders are tenant-specific, use dynamic prefix
  schema "orders" do
    field :tenant_id, :id
    belongs_to :product, MyApp.Catalog.Product
    timestamps()
  end
end
```

The `@schema_prefix` module attribute locks that schema to a specific PostgreSQL schema regardless of the repo's default prefix. Use this for truly shared data.

## The Honest Trade-offs

No pattern is free. Row-level tenancy means every index includes `tenant_id`, bloating your index sizes by 8 bytes per row for a bigint tenant_id. On a table with 100 million rows across all tenants, that's 800MB of index overhead. Your queries also need composite indexes — `(tenant_id, created_at)` instead of just `(created_at)` — which doubles index maintenance cost on writes.

Schema-based tenancy means schema count becomes a scaling dimension you have to monitor. PostgreSQL's catalog tables live in shared memory, and 50,000 schemas with 50 tables each means 2.5 million catalog entries. Query planning slows down. `pg_dump` gets sluggish. Some cloud providers impose hard limits on schema counts.

Database-per-tenant means your deployment pipeline needs to handle database provisioning, and you'll need serious automation. Every migration is a distributed operation. Monitoring multiplies — you now have N databases to watch for replication lag, connection exhaustion, and disk space.

Ecto gives you the primitives. The `prepare_query` callback, prefix support, and dynamic repos cover the implementation mechanics. What it can't give you is the discipline to use them correctly.

Build isolation tests. Make tenant scoping impossible to forget. Default to the simplest pattern that meets your requirements.

Multi-tenancy is a solved problem. The solutions just require engineering rigor to implement correctly.

Start with row-level. Move to schema-based when you have a concrete reason. Reserve database-per-tenant for when compliance requires it. And whatever you choose, make the wrong thing impossible to do silently.

Your future self — the one debugging a production incident at 2 AM — will thank you.

---

**Verification notes:** The code examples use Ecto 3.x APIs which remain current. The `prepare_query` callback was introduced in Ecto 3.0. The `default_options` callback is available in Ecto 3.1+. PostgreSQL schema limits and performance characteristics should be verified against your specific PostgreSQL version — behavior varies between PostgreSQL 12, 14, and 16. Connection memory estimates (5-10MB per connection) are approximate and depend on `work_mem` and other configuration settings.
