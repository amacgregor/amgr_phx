%{
title: "LiveView Patterns for Complex UIs",
category: "Programming",
tags: ["elixir", "phoenix", "liveview", "frontend"],
description: "Component design, nested live views, and handling complex state in LiveView",
published: false
}
---

LiveView's marketing writes checks that naive implementations cannot cash. The demos show real-time updates, forms that validate as you type, and interactive dashboards — all without writing JavaScript. What they do not show is what happens when your application grows beyond a single LiveView with a handful of assigns.

I have watched teams hit this wall. The initial velocity is intoxicating. Then the LiveView balloons to 800 lines. State becomes a tangled graph of interdependencies. Every change risks breaking three unrelated features. The team concludes that LiveView "does not scale" and reaches for React.

They are wrong. LiveView scales. But it demands architectural discipline that the simple examples never teach.

## The Complexity Threshold

LiveView changed significantly in version 0.18. Function components replaced the old `live_component` for stateless rendering. The `HEEx` engine brought compile-time validation. These changes were not cosmetic — they fundamentally altered how you should structure complex UIs.

The patterns that work for a CRUD interface collapse under the weight of a real application: drag-and-drop kanban boards, collaborative editors, multi-step wizards with branching logic, dashboards with dozens of independently updating widgets. These require deliberate architectural choices about component boundaries, state ownership, and communication patterns.

## Stateless vs Stateful Components

The first decision point is simple but consequential: does this component need its own state?

Function components are pure. They receive assigns, return markup, and have no lifecycle. They are fast, predictable, and should be your default choice.

```elixir
# A stateless function component — pure rendering
attr :user, :map, required: true
attr :show_email, :boolean, default: false

def user_card(assigns) do
  ~H"""
  <div class="user-card">
    <img src={@user.avatar_url} alt={@user.name} />
    <h3><%= @user.name %></h3>
    <%= if @show_email do %>
      <p class="email"><%= @user.email %></p>
    <% end %>
  </div>
  """
end
```

Use function components when the parent owns all the relevant state. The component just formats and displays it.

Live components are processes. They have their own state, their own lifecycle callbacks, and can handle events independently. This power comes with coordination costs.

```elixir
# A stateful live component — encapsulated behavior
defmodule MyAppWeb.CounterComponent do
  use MyAppWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, count: 0)}
  end

  def handle_event("increment", _, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end

  def render(assigns) do
    ~H"""
    <div>
      <span>Count: <%= @count %></span>
      <button phx-click="increment" phx-target={@myself}>+</button>
    </div>
    """
  end
end
```

The `phx-target={@myself}` is critical. Without it, the event bubbles to the parent LiveView. This is the encapsulation boundary — the component handles its own events.

Use live components when:
- The component has internal state the parent should not manage
- You need to isolate re-renders to a subtree of the DOM
- The component handles events that are purely internal to its function

Do not use live components just because a piece of UI feels "component-like." That instinct comes from React. In LiveView, the cost-benefit calculus is different.

## Component Communication Patterns

Components in isolation are useless. They need to communicate.

### Parent to Child: send_update

When a parent needs to push data to a live component, `send_update/3` is the mechanism.

```elixir
# In the parent LiveView
def handle_info({:user_updated, user}, socket) do
  send_update(UserProfileComponent, id: "user-profile", user: user)
  {:noreply, socket}
end
```

The component receives this in its `update/2` callback:

```elixir
# In the live component
def update(%{user: user} = assigns, socket) do
  {:ok, assign(socket, user: user, loading: false)}
end
```

This is targeted. You are sending data to a specific component instance by ID.

### Child to Parent: Events and Messages

Children communicate upward through events or explicit message passing.

```elixir
# Child component sends a message to parent
def handle_event("save", params, socket) do
  case save_item(params) do
    {:ok, item} ->
      send(self(), {:item_saved, item})
      {:noreply, socket}
    {:error, changeset} ->
      {:noreply, assign(socket, changeset: changeset)}
  end
end
```

The parent handles this in `handle_info/2`:

```elixir
def handle_info({:item_saved, item}, socket) do
  {:noreply, stream_insert(socket, :items, item)}
end
```

### Sibling Communication: PubSub

When components have no direct relationship — or when you want truly decoupled communication — Phoenix.PubSub is the answer.

```elixir
# Component A broadcasts
def handle_event("select_project", %{"id" => id}, socket) do
  Phoenix.PubSub.broadcast(MyApp.PubSub, "project:selected", {:project_selected, id})
  {:noreply, socket}
end

# Component B subscribes and listens
def mount(socket) do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "project:selected")
  {:ok, socket}
end

def handle_info({:project_selected, project_id}, socket) do
  {:noreply, assign(socket, current_project_id: project_id)}
end
```

PubSub shines when multiple unrelated components need to react to the same event. It also works across LiveView instances, which matters for collaborative features.

## Nested LiveViews vs Components

A nested LiveView is a separate Elixir process. A live component runs in the parent's process. This distinction has profound implications.

Nested LiveViews provide:
- **Process isolation**: A crash in the child does not crash the parent
- **Independent lifecycle**: The child can mount, connect, and disconnect on its own schedule
- **Memory isolation**: Heavy state in the child does not bloat the parent's process heap

The costs:
- **Coordination overhead**: Message passing between processes is slower than function calls
- **Complexity**: Managing the relationship between parent and child processes requires care
- **State synchronization**: Keeping state consistent across processes is your problem

```elixir
# Embedding a nested LiveView
<.live_component module={MyAppWeb.SidebarComponent} id="sidebar" />

# vs. a nested LiveView
<%= live_render(@socket, MyAppWeb.ChatLive, id: "chat-window", session: %{"room_id" => @room_id}) %>
```

Use nested LiveViews when:
- The feature is genuinely independent (a chat widget, an embedded editor)
- You need fault isolation
- The nested view has heavy state that should not bloat the parent

Use live components for everything else.

## Async Assigns for Long-Running Operations

Blocking in `mount/3` or `handle_event/3` is the fastest way to make your UI feel sluggish. If a database query takes 200ms, your users wait 200ms before seeing anything.

Phoenix 1.7 introduced `assign_async/3` to solve this cleanly.

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page_title, "Dashboard")
   |> assign_async(:stats, fn -> fetch_dashboard_stats() end)
   |> assign_async(:recent_activity, fn -> fetch_recent_activity() end)}
end

defp fetch_dashboard_stats do
  # Expensive aggregation query
  {:ok, %{users: count_users(), revenue: calculate_revenue()}}
end
```

In your template, handle the loading and error states:

```heex
<.async_result :let={stats} assign={@stats}>
  <:loading>
    <.spinner />
  </:loading>
  <:failed :let={_reason}>
    <p>Failed to load statistics</p>
  </:failed>

  <div class="stats-grid">
    <.stat_card label="Users" value={stats.users} />
    <.stat_card label="Revenue" value={stats.revenue} />
  </div>
</.async_result>
```

The UI renders immediately. The async data streams in as it becomes available. This is not a workaround — it is the correct pattern for any operation that might be slow.

For operations triggered by user actions, use `start_async/3`:

```elixir
def handle_event("generate_report", %{"type" => type}, socket) do
  {:noreply, start_async(socket, :report, fn -> generate_report(type) end)}
end

def handle_async(:report, {:ok, report}, socket) do
  {:noreply, assign(socket, report: report, generating: false)}
end

def handle_async(:report, {:exit, reason}, socket) do
  {:noreply, assign(socket, error: "Report generation failed", generating: false)}
end
```

## Optimistic UI Updates

Users do not care about your database transaction. They care about perceived responsiveness.

Optimistic UI updates the interface immediately, before the server confirms the action. If the server rejects it, you roll back.

```elixir
def handle_event("toggle_complete", %{"id" => id}, socket) do
  task = get_task(socket.assigns.tasks, id)

  # Optimistically update the UI
  updated_task = %{task | completed: !task.completed}
  socket = stream_insert(socket, :tasks, updated_task)

  # Then persist asynchronously
  {:noreply, start_async(socket, {:save_task, id}, fn ->
    Tasks.toggle_complete(id)
  end)}
end

def handle_async({:save_task, id}, {:ok, _task}, socket) do
  {:noreply, socket}  # Already updated optimistically
end

def handle_async({:save_task, id}, {:exit, _reason}, socket) do
  # Roll back the optimistic update
  task = Tasks.get_task!(id)
  {:noreply, stream_insert(socket, :tasks, task)}
end
```

For simpler cases, LiveView's built-in loading states often suffice:

```heex
<button phx-click="submit" phx-disable-with="Saving...">
  Save
</button>
```

The `JS` module provides finer control for complex loading states:

```elixir
def show_saving_indicator(js \\ %JS{}) do
  js
  |> JS.hide(to: "#save-button")
  |> JS.show(to: "#saving-spinner")
  |> JS.push("save")
end
```

## Form Handling Patterns

Forms are where LiveView's design shines — and where complexity accumulates fastest.

### The Form Abstraction

Always use `to_form/1` to wrap your changesets. This provides a consistent interface and handles edge cases.

```elixir
def mount(_params, _session, socket) do
  changeset = Articles.change_article(%Article{})
  {:ok, assign(socket, form: to_form(changeset))}
end

def handle_event("validate", %{"article" => params}, socket) do
  changeset =
    %Article{}
    |> Articles.change_article(params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, form: to_form(changeset))}
end
```

### Nested Associations

For forms with nested data, `inputs_for/1` handles the complexity:

```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:title]} label="Title" />

  <.inputs_for :let={tag_form} field={@form[:tags]}>
    <.input field={tag_form[:name]} label="Tag" />
    <button type="button" phx-click="remove_tag" phx-value-index={tag_form.index}>
      Remove
    </button>
  </.inputs_for>

  <button type="button" phx-click="add_tag">Add Tag</button>
  <button type="submit">Save</button>
</.form>
```

Handle the dynamic add/remove in your LiveView:

```elixir
def handle_event("add_tag", _, socket) do
  changeset = socket.assigns.form.source
  tags = Ecto.Changeset.get_field(changeset, :tags) || []
  changeset = Ecto.Changeset.put_assoc(changeset, :tags, tags ++ [%Tag{}])
  {:noreply, assign(socket, form: to_form(changeset))}
end

def handle_event("remove_tag", %{"index" => index}, socket) do
  changeset = socket.assigns.form.source
  tags = Ecto.Changeset.get_field(changeset, :tags) || []
  tags = List.delete_at(tags, String.to_integer(index))
  changeset = Ecto.Changeset.put_assoc(changeset, :tags, tags)
  {:noreply, assign(socket, form: to_form(changeset))}
end
```

## JS Hooks Integration

Sometimes LiveView's DOM patching is not enough. For rich text editors, charts, drag-and-drop, or third-party libraries, you need JavaScript hooks.

```javascript
// assets/js/hooks.js
let Hooks = {}

Hooks.Chart = {
  mounted() {
    this.chart = new Chart(this.el, {
      type: 'line',
      data: JSON.parse(this.el.dataset.chartData)
    })

    this.handleEvent("update_chart", ({data}) => {
      this.chart.data = data
      this.chart.update()
    })
  },

  updated() {
    // Called when LiveView updates the element
    const newData = JSON.parse(this.el.dataset.chartData)
    this.chart.data = newData
    this.chart.update()
  },

  destroyed() {
    this.chart.destroy()
  }
}

export default Hooks
```

Wire it up in your LiveView:

```heex
<canvas
  id="revenue-chart"
  phx-hook="Chart"
  data-chart-data={Jason.encode!(@chart_data)}
/>
```

Push updates from the server:

```elixir
def handle_info({:new_data_point, point}, socket) do
  chart_data = update_chart_data(socket.assigns.chart_data, point)

  {:noreply,
   socket
   |> assign(:chart_data, chart_data)
   |> push_event("update_chart", %{data: chart_data})}
end
```

The hook pattern creates a bridge. LiveView manages state and business logic. JavaScript handles DOM manipulation that requires direct access or third-party libraries.

## The Composition Principle

These patterns are not alternatives. They compose.

A complex dashboard might use: function components for layout and presentation, live components for widgets with internal state, async assigns to load widget data without blocking, PubSub to synchronize widgets when shared state changes, and JS hooks for the charting library.

The skill is not learning the patterns. It is learning when to apply each one.

LiveView applications fail when developers treat the framework as magic. They succeed when developers treat it as a toolkit with clear tradeoffs, and choose their tools deliberately.

The demos were not lying. LiveView can build complex, responsive, real-time UIs with minimal JavaScript. But it cannot do it for you. You still have to think.

---

*Key claims to verify with current documentation: The async assigns API (`assign_async`, `start_async`, `handle_async`) was introduced in Phoenix LiveView 0.18.16+. Verify the exact version and any API changes in recent releases. The `inputs_for` syntax shown uses the HEEx component syntax from LiveView 0.18+.*
