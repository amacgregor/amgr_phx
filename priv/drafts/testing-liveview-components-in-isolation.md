%{
title: "Testing LiveView Components in Isolation",
category: "Programming",
tags: ["elixir", "phoenix", "liveview", "testing"],
description: "Component testing strategies, mocking, and testing JS hooks",
published: false
}
---

Most LiveView tutorials gloss over testing. They show you the happy path—mount a view, click a button, assert the result—and call it a day. But real applications have dozens of components with complex interdependencies, JavaScript hooks that manipulate the DOM, and stateful interactions that span multiple user actions. Testing these in isolation is where teams struggle.

I've seen codebases where component tests are either absent entirely or so tightly coupled to parent LiveViews that changing one component breaks thirty unrelated tests. Neither situation is acceptable for production systems.

This article covers how to test LiveView components properly: stateless function components, stateful LiveComponents, JavaScript hooks, and the mocking strategies that make isolated testing possible. The goal is a test suite that's fast, maintainable, and actually catches bugs before they hit production.

---

## A Quick Refresher on LiveView Testing Basics

Phoenix ships with `Phoenix.LiveViewTest`, a module that provides the core testing primitives. If you've written any LiveView tests, you've likely used `live/2` to mount a view and `render_click/2` to simulate user interactions.

```elixir
defmodule MyAppWeb.CounterLiveTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "increments counter on click", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/counter")

    assert render_click(view, "increment") =~ "Count: 1"
  end
end
```

This works for full-page LiveViews. But components present a different challenge. They don't have their own routes. They exist within parent contexts. They receive assigns from above and sometimes send messages back up.

The key insight: you need to test components without spinning up their entire parent hierarchy.

---

## Testing Stateless Function Components

Function components are the simpler case. They're pure functions that take assigns and return HEEx. No state, no lifecycle, no messages. Testing them is straightforward—render the component directly and assert against the output.

Phoenix 1.7+ provides `Phoenix.LiveViewTest.render_component/2` for exactly this purpose:

```elixir
defmodule MyAppWeb.Components.ButtonTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias MyAppWeb.Components.Button

  describe "render/1" do
    test "renders primary variant with correct classes" do
      html = render_component(&Button.button/1,
        variant: :primary,
        label: "Submit"
      )

      assert html =~ "bg-blue-600"
      assert html =~ "Submit"
    end

    test "renders disabled state" do
      html = render_component(&Button.button/1,
        variant: :primary,
        label: "Submit",
        disabled: true
      )

      assert html =~ "disabled"
      assert html =~ "opacity-50"
    end

    test "renders with custom class additions" do
      html = render_component(&Button.button/1,
        variant: :secondary,
        label: "Cancel",
        class: "ml-4"
      )

      assert html =~ "ml-4"
      assert html =~ "bg-gray-200"
    end
  end
end
```

The pattern is simple: call `render_component/2` with a function capture and a keyword list of assigns. You get back rendered HTML as a string.

One thing to watch: function components that use slots require slightly different handling. You need to pass the slot content as part of the assigns:

```elixir
test "renders card with header and body slots" do
  html = render_component(&Card.card/1,
    inner_block: [
      %{__slot__: :header, inner_block: fn _, _ -> "Card Title" end},
      %{__slot__: :inner_block, inner_block: fn _, _ -> "Card content here" end}
    ]
  )

  assert html =~ "Card Title"
  assert html =~ "Card content here"
end
```

The slot syntax is admittedly awkward. For complex slot scenarios, I often create a test helper that wraps this boilerplate.

---

## Testing Stateful LiveComponents in Isolation

LiveComponents are where things get interesting. They have their own lifecycle (`mount/1`, `update/2`, `handle_event/3`), they can hold state, and they communicate with parents via `send/2` or by emitting events that parents handle.

The trick is creating a minimal test harness—a bare-bones LiveView that hosts your component without the complexity of your actual parent views.

```elixir
defmodule MyAppWeb.Components.SearchInputTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  # Minimal harness LiveView for testing
  defmodule TestHarness do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <.live_component
        module={MyAppWeb.Components.SearchInput}
        id="test-search"
        placeholder={@placeholder}
        on_search={@on_search}
      />
      """
    end

    def mount(_params, _session, socket) do
      {:ok, assign(socket, placeholder: "Search...", on_search: nil)}
    end

    def handle_info({:search, query}, socket) do
      {:noreply, assign(socket, last_search: query)}
    end
  end

  describe "SearchInput component" do
    test "renders with placeholder", %{conn: conn} do
      {:ok, view, html} = live_isolated(conn, TestHarness)

      assert html =~ "Search..."
    end

    test "emits search event on form submit", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestHarness)

      view
      |> element("form")
      |> render_submit(%{"query" => "elixir testing"})

      # Assert the component updated
      assert render(view) =~ "elixir testing"
    end

    test "debounces rapid input changes", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestHarness)

      # Simulate rapid typing
      view |> element("input") |> render_change(%{"query" => "e"})
      view |> element("input") |> render_change(%{"query" => "el"})
      view |> element("input") |> render_change(%{"query" => "eli"})

      # Only one search should be triggered after debounce
      Process.sleep(350)  # Wait for debounce

      # Assert debounced behavior
      assert render(view) =~ "eli"
    end
  end
end
```

The key function here is `live_isolated/2`. It mounts your harness LiveView without needing a router entry. The harness provides just enough context for your component to function.

---

## Mocking Parent Assigns and Context

Real components often depend on data passed from parents: current user, permissions, feature flags, loaded records. You need to simulate these without instantiating the entire parent stack.

I use a combination of harness assigns and, when necessary, Mox for external dependencies:

```elixir
defmodule MyAppWeb.Components.UserCardTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  defmodule TestHarness do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <.live_component
        module={MyAppWeb.Components.UserCard}
        id="user-card"
        user={@user}
        current_user={@current_user}
        permissions={@permissions}
      />
      """
    end

    def mount(_params, session, socket) do
      {:ok, assign(socket,
        user: session["user"],
        current_user: session["current_user"],
        permissions: session["permissions"] || []
      )}
    end
  end

  describe "UserCard component" do
    test "shows edit button for admin users", %{conn: conn} do
      user = %{id: 1, name: "John Doe", email: "john@example.com"}
      current_user = %{id: 2, role: :admin}

      {:ok, view, html} = live_isolated(conn, TestHarness,
        session: %{
          "user" => user,
          "current_user" => current_user,
          "permissions" => [:edit_users]
        }
      )

      assert html =~ "Edit"
      assert html =~ "John Doe"
    end

    test "hides edit button for regular users", %{conn: conn} do
      user = %{id: 1, name: "John Doe", email: "john@example.com"}
      current_user = %{id: 2, role: :member}

      {:ok, view, html} = live_isolated(conn, TestHarness,
        session: %{
          "user" => user,
          "current_user" => current_user,
          "permissions" => []
        }
      )

      refute html =~ "Edit"
      assert html =~ "John Doe"
    end

    test "fetches additional user data on expand", %{conn: conn} do
      user = %{id: 1, name: "John Doe", email: "john@example.com"}

      # Mock the user service
      expect(MyApp.UserServiceMock, :get_user_details, fn 1 ->
        {:ok, %{bio: "Elixir developer", joined: ~D[2020-01-15]}}
      end)

      {:ok, view, _html} = live_isolated(conn, TestHarness,
        session: %{
          "user" => user,
          "current_user" => %{id: 2, role: :member},
          "permissions" => []
        }
      )

      html = view
        |> element("[data-action='expand']")
        |> render_click()

      assert html =~ "Elixir developer"
      assert html =~ "2020"
    end
  end
end
```

The session map passed to `live_isolated/3` flows into your harness's `mount/3`, letting you inject whatever context the component needs.

---

## Testing Component Interactions and send_update

Components that coordinate with each other—or send updates back to parents—require testing the message flow, not just the rendered output.

Consider a modal component that notifies its parent when closed:

```elixir
defmodule MyAppWeb.Components.ModalTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  defmodule TestHarness do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <div>
        <p>Modal open: <%= @modal_open %></p>
        <%= if @modal_open do %>
          <.live_component
            module={MyAppWeb.Components.Modal}
            id="test-modal"
            title="Confirm Action"
            on_close={fn -> send(self(), :modal_closed) end}
          >
            <p>Are you sure?</p>
          </.live_component>
        <% end %>
      </div>
      """
    end

    def mount(_params, _session, socket) do
      {:ok, assign(socket, modal_open: true)}
    end

    def handle_info(:modal_closed, socket) do
      {:noreply, assign(socket, modal_open: false)}
    end
  end

  test "closes modal and notifies parent", %{conn: conn} do
    {:ok, view, html} = live_isolated(conn, TestHarness)

    assert html =~ "Modal open: true"
    assert html =~ "Confirm Action"

    # Click close button
    view
    |> element("[data-action='close-modal']")
    |> render_click()

    # Modal should be closed
    html = render(view)
    refute html =~ "Confirm Action"
    assert html =~ "Modal open: false"
  end
end
```

For testing `send_update/3` between sibling components, your harness needs to coordinate both:

```elixir
defmodule TestHarness do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <.live_component module={FilterPanel} id="filters" />
    <.live_component module={ResultsList} id="results" filters={@active_filters} />
    """
  end

  def handle_info({:filters_changed, filters}, socket) do
    send_update(ResultsList, id: "results", filters: filters)
    {:noreply, assign(socket, active_filters: filters)}
  end
end
```

Test the full flow: interact with FilterPanel, verify ResultsList updates accordingly.

---

## Testing JavaScript Hooks: Strategies and Limitations

Here's the hard truth: you cannot fully test JavaScript hooks with ExUnit. The BEAM doesn't run JavaScript. Phoenix's test helpers simulate the server side of LiveView—they don't spin up a browser.

That said, you have three options:

**1. Test the Elixir side of hook communication**

Hooks communicate via `pushEvent` and `handleEvent`. You can test that your LiveView handles these events correctly:

```elixir
test "handles chart data request from JS hook", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/dashboard")

  # Simulate the event that a JS hook would push
  render_hook(view, "request-chart-data", %{
    "chart_id" => "revenue",
    "date_range" => "last_30_days"
  })

  # Assert the server responded with the expected data
  # The actual chart rendering happens in JS, but we verify
  # the data pipeline works
  assert_push_event(view, "chart-data", %{
    chart_id: "revenue",
    data: data
  })

  assert length(data) == 30
end
```

**2. Use Wallaby or Hound for integration tests**

For critical JS hook functionality, browser-based integration tests are unavoidable:

```elixir
# Using Wallaby
defmodule MyAppWeb.ChartIntegrationTest do
  use MyAppWeb.FeatureCase, async: false
  use Wallaby.Feature

  feature "chart renders with live data", %{session: session} do
    session
    |> visit("/dashboard")
    |> assert_has(css(".chart-container"))
    |> assert_has(css(".chart-container svg"))  # Chart rendered
    |> click(button("Last 7 Days"))
    |> assert_has(css(".chart-container[data-range='7']"))
  end
end
```

**3. Test JS in isolation with Jest**

Move complex hook logic into testable JavaScript modules:

```javascript
// assets/js/hooks/chart.test.js
import { parseChartData, calculateTrend } from './chart';

describe('chart utilities', () => {
  test('parseChartData handles empty dataset', () => {
    expect(parseChartData([])).toEqual({ labels: [], values: [] });
  });

  test('calculateTrend returns positive for upward data', () => {
    const data = [10, 12, 15, 18, 22];
    expect(calculateTrend(data)).toBe('positive');
  });
});
```

The hybrid approach—ExUnit for Elixir logic, Jest for JS logic, Wallaby for integration—provides the best coverage without over-relying on slow browser tests.

---

## Snapshot Testing for Complex Component Output

When components produce complex, structured HTML—data tables, nested forms, rich text displays—asserting individual elements becomes tedious. Snapshot testing captures the entire output and alerts you when it changes.

Elixir doesn't have built-in snapshot testing, but it's easy to implement:

```elixir
defmodule MyAppWeb.SnapshotHelpers do
  @snapshot_dir "test/snapshots"

  def assert_snapshot(html, name) do
    path = Path.join(@snapshot_dir, "#{name}.html")
    normalized = normalize_html(html)

    if File.exists?(path) do
      expected = File.read!(path)
      if normalized != expected do
        File.write!(Path.join(@snapshot_dir, "#{name}.new.html"), normalized)
        flunk """
        Snapshot mismatch for #{name}.
        New output written to #{name}.new.html
        Run `mix test.update_snapshots` to accept changes.
        """
      end
    else
      File.mkdir_p!(@snapshot_dir)
      File.write!(path, normalized)
      IO.puts("Created new snapshot: #{name}")
    end
  end

  defp normalize_html(html) do
    html
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/> </, ">\n<")
    |> String.trim()
  end
end
```

Usage in tests:

```elixir
test "renders complex data table correctly", %{conn: conn} do
  users = [
    %{id: 1, name: "Alice", role: :admin, last_login: ~U[2025-01-15 10:30:00Z]},
    %{id: 2, name: "Bob", role: :member, last_login: ~U[2025-01-14 09:00:00Z]}
  ]

  html = render_component(&UserTable.table/1, users: users, sortable: true)

  assert_snapshot(html, "user_table_with_data")
end
```

Snapshots work best for stable components. For components under active development, traditional assertions are less brittle.

---

## Putting It Together

A well-tested LiveView component suite combines these strategies:

1. **Function components**: Direct `render_component/2` calls with assigns
2. **LiveComponents**: Isolated harness LiveViews with `live_isolated/2`
3. **Context injection**: Session maps and Mox for external dependencies
4. **Inter-component communication**: Harnesses that simulate parent coordination
5. **JS hooks**: `render_hook/3` for Elixir side, separate JS tests for logic, Wallaby for integration
6. **Complex output**: Snapshot testing where assertion counts would explode

The investment pays off. I've worked on LiveView applications with 200+ components where the test suite catches regressions within minutes. The alternative—manual testing or tests so coupled they break constantly—is far more expensive.

Start with the patterns that match your current pain points. If your components are simple, function component tests might be all you need. If you're building a complex interactive system, invest in the harness infrastructure early. Either way, test the components in isolation. Your future self will thank you.

---

**Key claims to verify with current documentation:**

- `render_component/2` function signature and behavior (check Phoenix.LiveViewTest docs for your version)
- `live_isolated/2` availability and options (added in LiveView 0.17+)
- `render_hook/3` function signature for testing hook events
- `assert_push_event/3` for verifying server-to-client pushes
- Slot syntax for testing function components with slots may vary by Phoenix version
