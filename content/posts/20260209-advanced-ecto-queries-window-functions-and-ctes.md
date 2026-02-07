%{
title: "Advanced Ecto Queries: Window Functions and CTEs",
category: "Programming",
tags: ["elixir", "ecto", "postgresql", "sql"],
description: "Using window functions, CTEs, and advanced SQL features through Ecto",
published: true
}
---

You will hit the wall. Every developer working with Ecto eventually does.

The query starts simple. Fetch users with their posts, filter by date, order by creation time. Ecto handles this beautifully. Then the requirements evolve. Calculate each user's rank in a leaderboard. Show running totals over time. Traverse an organizational hierarchy. Suddenly, `from`, `join`, `where`, and `select` feel like bringing a knife to a gunfight.

This is the moment most developers reach for raw SQL and abandon Ecto entirely. That's a mistake. Ecto provides the tools to express sophisticated SQL constructs—window functions, Common Table Expressions, recursive queries, lateral joins—while preserving composability and type safety. You just need to know where to look.

## When Basic Ecto Falls Short

Ecto's query DSL covers roughly 80% of what you'll need in a typical application. Joins, aggregations, subqueries, filtering—all handled elegantly. But certain problems require SQL features that have no direct DSL representation.

Consider these scenarios:

**Ranking and pagination within groups**: You need the top 3 posts per category, not just the top 3 posts overall. A simple `limit` won't work because it operates on the entire result set.

**Running calculations**: Financial reports demand running totals, moving averages, or cumulative sums. Each row's value depends on all previous rows in a sequence.

**Hierarchical data**: Organizational charts, nested categories, threaded comments—structures where a record references its parent, and you need to traverse the entire tree.

**Row-to-row comparisons**: Time-series analysis requires comparing each row to its predecessor. What was yesterday's value? What's the week-over-week change?

These problems share a common characteristic: they require awareness of other rows while computing a value for the current row. Standard aggregations collapse rows into groups. Window functions and CTEs let you see across rows without collapsing them.

## Window Functions: The Power of OVER

Window functions perform calculations across a set of rows related to the current row. Unlike `GROUP BY`, they don't reduce the number of rows returned. Every row gets its own computed value based on its "window" of related rows.

Ecto exposes window functions through `fragment/1`, which lets you embed raw SQL expressions within your queries.

### ROW_NUMBER: Numbering and Deduplication

The most common window function. Assign sequential numbers to rows within partitions.

```elixir
defmodule MyApp.Posts do
  import Ecto.Query

  def with_row_numbers do
    from p in Post,
      select: %{
        id: p.id,
        title: p.title,
        category_id: p.category_id,
        row_num: fragment(
          "ROW_NUMBER() OVER (PARTITION BY ? ORDER BY ? DESC)",
          p.category_id,
          p.published_at
        )
      }
  end

  def top_n_per_category(n) do
    numbered = with_row_numbers()

    from p in subquery(numbered),
      where: p.row_num <= ^n,
      select: p
  end
end
```

This generates:

```sql
SELECT p0."id", p0."title", p0."category_id",
       ROW_NUMBER() OVER (PARTITION BY p0."category_id"
                          ORDER BY p0."published_at" DESC) as row_num
FROM "posts" AS p0
```

The `PARTITION BY` clause restarts numbering for each category. The `ORDER BY` within the window determines the sequence. Wrap it in a subquery to filter by row number.

### RANK and DENSE_RANK: Leaderboards

`RANK` assigns positions with gaps for ties. `DENSE_RANK` assigns positions without gaps.

```elixir
def leaderboard do
  from u in User,
    join: s in Score, on: s.user_id == u.id,
    group_by: [u.id, u.name],
    select: %{
      user_id: u.id,
      name: u.name,
      total_score: sum(s.points),
      rank: fragment(
        "RANK() OVER (ORDER BY SUM(?) DESC)",
        s.points
      )
    }
end
```

Generated SQL:

```sql
SELECT u0."id", u0."name", SUM(s1."points"),
       RANK() OVER (ORDER BY SUM(s1."points") DESC)
FROM "users" AS u0
INNER JOIN "scores" AS s1 ON s1."user_id" = u0."id"
GROUP BY u0."id", u0."name"
```

Two players with 100 points both get rank 1. The next player gets rank 3, not rank 2. Use `DENSE_RANK` if you want consecutive rankings.

### LAG and LEAD: Looking Backward and Forward

Time-series analysis lives and dies by row-to-row comparison. `LAG` accesses previous rows; `LEAD` accesses subsequent rows.

```elixir
def daily_transactions_with_change do
  from t in Transaction,
    where: t.account_id == ^account_id,
    order_by: [asc: t.date],
    select: %{
      date: t.date,
      amount: t.amount,
      previous_amount: fragment(
        "LAG(?, 1) OVER (ORDER BY ?)",
        t.amount,
        t.date
      ),
      daily_change: fragment(
        "? - COALESCE(LAG(?, 1) OVER (ORDER BY ?), 0)",
        t.amount,
        t.amount,
        t.date
      )
    }
end
```

The `1` in `LAG(?, 1)` specifies one row back. You can look further: `LAG(?, 7)` for week-over-week in daily data. The `COALESCE` handles the first row, which has no predecessor.

## Running Totals and Moving Averages

Financial reporting's bread and butter. Window functions with frame specifications make this straightforward.

```elixir
def running_balance do
  from t in Transaction,
    where: t.account_id == ^account_id,
    order_by: [asc: t.date],
    select: %{
      date: t.date,
      amount: t.amount,
      running_total: fragment(
        "SUM(?) OVER (ORDER BY ? ROWS UNBOUNDED PRECEDING)",
        t.amount,
        t.date
      )
    }
end
```

The `ROWS UNBOUNDED PRECEDING` clause tells PostgreSQL to include all rows from the start of the partition up to (and including) the current row.

For a moving average, specify a fixed window:

```elixir
def seven_day_moving_average do
  from t in Transaction,
    order_by: [asc: t.date],
    select: %{
      date: t.date,
      amount: t.amount,
      moving_avg: fragment(
        "AVG(?) OVER (ORDER BY ? ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)",
        t.amount,
        t.date
      )
    }
end
```

This computes the average of the current row and the six preceding rows. Note: this is row-based, not calendar-based. If you have gaps in your dates, you'll need a different approach involving date arithmetic.

## Common Table Expressions: WITH Queries

CTEs let you define named temporary result sets within a query. They improve readability, enable recursive queries, and sometimes help the query planner.

Ecto 3.x introduced `with_cte/3` for this purpose.

```elixir
def monthly_summary_with_comparison do
  monthly_totals =
    from t in Transaction,
      group_by: fragment("DATE_TRUNC('month', ?)", t.date),
      select: %{
        month: fragment("DATE_TRUNC('month', ?)", t.date),
        total: sum(t.amount)
      }

  "monthly_totals"
  |> with_cte("monthly_totals", as: ^monthly_totals)
  |> select([m], %{
    month: m.month,
    total: m.total,
    prev_month_total: fragment(
      "LAG(?, 1) OVER (ORDER BY ?)",
      m.total,
      m.month
    )
  })
end
```

The CTE defines `monthly_totals` as a named result set. The main query then references it and applies a window function. This separates the aggregation logic from the comparison logic.

CTEs shine when you need to reference the same subquery multiple times:

```elixir
def high_value_customers_analysis do
  high_value =
    from c in Customer,
      join: o in Order, on: o.customer_id == c.id,
      group_by: c.id,
      having: sum(o.total) > 10000,
      select: %{id: c.id, lifetime_value: sum(o.total)}

  "high_value_customers"
  |> with_cte("high_value_customers", as: ^high_value)
  |> join(:inner, [hv], o in Order, on: o.customer_id == hv.id)
  |> group_by([hv, o], fragment("DATE_TRUNC('month', ?)", o.created_at))
  |> select([hv, o], %{
    month: fragment("DATE_TRUNC('month', ?)", o.created_at),
    order_count: count(o.id),
    revenue: sum(o.total)
  })
end
```

Without the CTE, you'd either repeat the subquery or resort to multiple database round-trips.

## Recursive CTEs: Hierarchical Data

The real power of CTEs emerges with recursion. Organizational hierarchies, category trees, bill-of-materials explosions—anywhere you have self-referential data.

Consider an employees table where each employee has a `manager_id` pointing to their manager:

```elixir
def org_chart_from(employee_id) do
  # Base case: the starting employee
  base_query =
    from e in Employee,
      where: e.id == ^employee_id,
      select: %{
        id: e.id,
        name: e.name,
        manager_id: e.manager_id,
        depth: 0
      }

  # Recursive case: employees managed by someone in the tree
  recursive_query =
    from e in Employee,
      join: tree in "org_tree", on: e.manager_id == tree.id,
      select: %{
        id: e.id,
        name: e.name,
        manager_id: e.manager_id,
        depth: tree.depth + 1
      }

  union_query = union_all(base_query, ^recursive_query)

  "org_tree"
  |> recursive_ctes(true)
  |> with_cte("org_tree", as: ^union_query)
  |> select([t], t)
  |> order_by([t], [asc: t.depth, asc: t.name])
end
```

This generates:

```sql
WITH RECURSIVE "org_tree" AS (
  SELECT e0."id", e0."name", e0."manager_id", 0 AS depth
  FROM "employees" AS e0
  WHERE e0."id" = $1

  UNION ALL

  SELECT e0."id", e0."name", e0."manager_id", o1."depth" + 1
  FROM "employees" AS e0
  INNER JOIN "org_tree" AS o1 ON e0."manager_id" = o1."id"
)
SELECT * FROM "org_tree"
ORDER BY depth, name
```

The `recursive_ctes(true)` call is essential. Without it, Ecto won't emit the `RECURSIVE` keyword, and the query will fail.

A word of caution: recursive CTEs can be expensive. Add a depth limit to prevent runaway queries:

```elixir
recursive_query =
  from e in Employee,
    join: tree in "org_tree", on: e.manager_id == tree.id,
    where: tree.depth < 10,  # Safety limit
    select: %{...}
```

## Lateral Joins: Correlated Subqueries

Lateral joins let a subquery reference columns from preceding tables in the `FROM` clause. This is powerful for "top N per group" patterns and complex correlations.

Ecto doesn't have direct lateral join syntax, but `fragment` handles it:

```elixir
def latest_orders_per_customer(n) do
  from c in Customer,
    join: o in fragment(
      "LATERAL (SELECT * FROM orders WHERE customer_id = ? ORDER BY created_at DESC LIMIT ?) AS orders",
      c.id,
      ^n
    ),
    select: %{
      customer_name: c.name,
      order_id: fragment("(?).id", o),
      order_total: fragment("(?).total", o),
      order_date: fragment("(?).created_at", o)
    }
end
```

The `LATERAL` keyword allows the subquery to see `c.id` from the outer table. Each customer gets their own subquery execution, returning their N most recent orders.

This pattern often outperforms window function approaches for top-N-per-group queries, especially when N is small and the table is large. The lateral subquery can use indexes effectively.

## Putting It Together: Real Examples

### Analytics Dashboard Query

A SaaS metrics dashboard needs daily active users, 7-day retention, and growth rates:

```elixir
def daily_metrics(start_date, end_date) do
  daily_actives =
    from e in Event,
      where: e.date >= ^start_date and e.date <= ^end_date,
      group_by: e.date,
      select: %{
        date: e.date,
        dau: count(e.user_id, :distinct)
      }

  "daily_actives"
  |> with_cte("daily_actives", as: ^daily_actives)
  |> select([d], %{
    date: d.date,
    dau: d.dau,
    dau_7d_avg: fragment(
      "AVG(?) OVER (ORDER BY ? ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)",
      d.dau,
      d.date
    ),
    wow_growth: fragment(
      "ROUND((? - LAG(?, 7) OVER (ORDER BY ?))::numeric /
       NULLIF(LAG(?, 7) OVER (ORDER BY ?), 0) * 100, 2)",
      d.dau, d.dau, d.date, d.dau, d.date
    )
  })
  |> order_by([d], asc: d.date)
end
```

One query. Daily actives, smoothed trend line, and week-over-week growth percentage. No application-level loops. No multiple database round-trips.

### Category Breadcrumbs

E-commerce sites need breadcrumb navigation. With recursive CTEs:

```elixir
def category_breadcrumb(category_id) do
  base =
    from c in Category,
      where: c.id == ^category_id,
      select: %{id: c.id, name: c.name, parent_id: c.parent_id, path: c.name}

  recursive =
    from c in Category,
      join: bc in "breadcrumb", on: c.id == bc.parent_id,
      select: %{
        id: c.id,
        name: c.name,
        parent_id: c.parent_id,
        path: fragment("? || ' > ' || ?", c.name, bc.path)
      }

  "breadcrumb"
  |> recursive_ctes(true)
  |> with_cte("breadcrumb", as: ^union_all(base, ^recursive))
  |> where([b], is_nil(b.parent_id))
  |> select([b], b.path)
end
```

Start from the target category, walk up to the root, accumulating the path. The final result: "Electronics > Computers > Laptops".

## The Composability Argument

You might ask: why not just write raw SQL? For complex analytical queries, raw SQL is sometimes the right choice. But Ecto's approach offers tangible benefits.

**Dynamic composition**: Fragments compose with Ecto's query pipeline. Add filters, modify ordering, wrap in further subqueries—all programmatically.

```elixir
def leaderboard(opts \\ []) do
  base = leaderboard_query()

  base
  |> maybe_filter_by_region(opts[:region])
  |> maybe_filter_by_date_range(opts[:start_date], opts[:end_date])
  |> maybe_limit(opts[:top_n])
end
```

**Parameter safety**: Ecto handles parameter binding. No SQL injection risks from interpolated values.

**Schema integration**: Queries can still leverage your Ecto schemas for associations, virtual fields, and validation.

Raw SQL has its place. But reaching for it reflexively means abandoning these benefits prematurely.

## Closing Thoughts

Ecto's query DSL is not the ceiling. It's the foundation. When you need window functions for analytics, CTEs for complex multi-step transformations, or recursive queries for hierarchical data, the tools exist. They require `fragment` and a deeper understanding of SQL, but they remain within Ecto's composable framework.

The key insight: Ecto is a query builder, not a query limiter. It generates SQL. When you need SQL features beyond the DSL, you embed them directly. The abstraction doesn't break. It extends.

Master these techniques, and you'll stop seeing "complex SQL requirements" as a reason to abandon Ecto. You'll see them as exactly the problems Ecto was designed to help you solve.

---

<!-- **Claims to verify with current data:**

- Ecto version compatibility: The CTE syntax (`with_cte/3`, `recursive_ctes/1`) was introduced in Ecto 3.x. Verify specific version requirements against current Ecto documentation.
- PostgreSQL version requirements: Some window function features and CTE capabilities vary by PostgreSQL version. LATERAL joins require PostgreSQL 9.3+.
- Performance characteristics of recursive CTEs vs. application-level recursion may vary based on data distribution and indexes. Benchmark with your specific dataset. -->
