%{
title: "Building Real-Time Dashboards with LiveView",
category: "Programming",
tags: ["elixir", "phoenix", "liveview", "real-time", "dashboards"],
description: "Telemetry integration, charting, and handling high-frequency updates in LiveView",
published: false
}
---

Most real-time dashboard implementations are overcomplicated. Developers reach for WebSocket libraries, external state management, and JavaScript frameworks when Phoenix LiveView already handles the hard parts. The BEAM's process model and LiveView's server-rendered approach make real-time dashboards almost trivially simple to build—if you understand the underlying patterns.

I've built several production dashboards that handle thousands of concurrent users pushing metrics at sub-second intervals. The architecture that works isn't the one you'd expect from traditional web development. It's simpler. Let me walk through how to build one properly.

## The Architecture That Actually Works

Real-time dashboards have a fundamental tension: data arrives frequently, but users can only perceive updates at roughly 10-20 frames per second. Pushing every metric update to the browser wastes bandwidth and CPU cycles. The architecture needs to decouple data ingestion from data presentation.

Here's the pattern I use:

```elixir
defmodule MyApp.Metrics.Collector do
  use GenServer

  @flush_interval 100  # milliseconds

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record(metric_name, value) do
    GenServer.cast(__MODULE__, {:record, metric_name, value, System.monotonic_time()})
  end

  def init(_opts) do
    schedule_flush()
    {:ok, %{buffer: %{}}}
  end

  def handle_cast({:record, name, value, timestamp}, state) do
    buffer = Map.update(state.buffer, name, [{value, timestamp}], &[{value, timestamp} | &1])
    {:noreply, %{state | buffer: buffer}}
  end

  def handle_info(:flush, state) do
    aggregated = aggregate_buffer(state.buffer)
    Phoenix.PubSub.broadcast(MyApp.PubSub, "metrics:updates", {:metrics, aggregated})
    schedule_flush()
    {:noreply, %{state | buffer: %{}}}
  end

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp aggregate_buffer(buffer) do
    Map.new(buffer, fn {name, values} ->
      {name, %{
        avg: Enum.sum(Enum.map(values, &elem(&1, 0))) / length(values),
        min: Enum.min(Enum.map(values, &elem(&1, 0))),
        max: Enum.max(Enum.map(values, &elem(&1, 0))),
        count: length(values)
      }}
    end)
  end
end
```

The collector buffers incoming metrics and flushes aggregated data every 100 milliseconds. This transforms potentially thousands of individual data points into a single broadcast. The PubSub layer handles distribution to all connected LiveView processes.

The LiveView subscribes on mount:

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "metrics:updates")
    end

    {:ok, assign(socket, metrics: %{}, chart_data: [])}
  end

  def handle_info({:metrics, aggregated}, socket) do
    chart_data = update_chart_data(socket.assigns.chart_data, aggregated)
    {:noreply, assign(socket, metrics: aggregated, chart_data: chart_data)}
  end

  defp update_chart_data(existing, new_metrics) do
    timestamp = DateTime.utc_now()
    point = Map.put(new_metrics, :timestamp, timestamp)

    # Keep last 60 data points (6 seconds at 100ms intervals)
    [point | existing] |> Enum.take(60)
  end
end
```

This separation—collector, PubSub, LiveView—gives you three independent knobs to tune. You can adjust the flush interval without touching the LiveView. You can add more collectors without changing the broadcast logic. Each piece has one job.

## Telemetry Integration

Erlang's telemetry library provides a standardized way to emit metrics from any part of your application. Phoenix, Ecto, and most well-designed Elixir libraries already emit telemetry events. Tapping into them is straightforward.

First, attach handlers during application startup:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    attach_telemetry_handlers()

    children = [
      MyApp.Repo,
      {Phoenix.PubSub, name: MyApp.PubSub},
      MyApp.Metrics.Collector,
      MyAppWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end

  defp attach_telemetry_handlers do
    :telemetry.attach_many(
      "myapp-metrics",
      [
        [:phoenix, :endpoint, :stop],
        [:myapp, :repo, :query],
        [:vm, :memory],
        [:vm, :total_run_queue_lengths]
      ],
      &MyApp.Metrics.TelemetryHandler.handle_event/4,
      nil
    )
  end
end
```

The handler transforms telemetry events into metrics for the collector:

```elixir
defmodule MyApp.Metrics.TelemetryHandler do
  alias MyApp.Metrics.Collector

  def handle_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Collector.record("http.request.duration", duration_ms)
    Collector.record("http.request.count", 1)

    status_bucket = div(metadata.conn.status, 100) * 100
    Collector.record("http.status.#{status_bucket}", 1)
  end

  def handle_event([:myapp, :repo, :query], measurements, _metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.total_time, :native, :millisecond)
    Collector.record("db.query.duration", duration_ms)
  end

  def handle_event([:vm, :memory], measurements, _metadata, _config) do
    Collector.record("vm.memory.total", measurements.total)
    Collector.record("vm.memory.processes", measurements.processes)
    Collector.record("vm.memory.binary", measurements.binary)
  end

  def handle_event([:vm, :total_run_queue_lengths], measurements, _metadata, _config) do
    Collector.record("vm.run_queue.total", measurements.total)
    Collector.record("vm.run_queue.cpu", measurements.cpu)
  end
end
```

For VM metrics, you'll want to poll periodically rather than wait for events:

```elixir
defmodule MyApp.Metrics.VMPoller do
  use GenServer

  @poll_interval 1000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    schedule_poll()
    {:ok, %{}}
  end

  def handle_info(:poll, state) do
    :telemetry.execute([:vm, :memory], :erlang.memory())
    :telemetry.execute([:vm, :total_run_queue_lengths], %{
      total: :erlang.statistics(:total_run_queue_lengths),
      cpu: :erlang.statistics(:total_run_queue_lengths_all)
    })

    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end
```

## Charting: VegaLite vs Chart.js Hooks

You have two solid options for rendering charts in LiveView: VegaLite with the `vega_lite` library, or Chart.js via JavaScript hooks. Each has tradeoffs.

### VegaLite Approach

VegaLite integrates cleanly with LiveView through server-side specification:

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view
  alias VegaLite, as: Vl

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4">
      <div>
        <h3>Request Latency</h3>
        <%= raw(@latency_chart) %>
      </div>
      <div>
        <h3>Memory Usage</h3>
        <%= raw(@memory_chart) %>
      </div>
    </div>
    """
  end

  def handle_info({:metrics, aggregated}, socket) do
    chart_data = update_chart_data(socket.assigns.chart_data, aggregated)

    latency_chart = build_latency_chart(chart_data)
    memory_chart = build_memory_chart(chart_data)

    {:noreply, assign(socket,
      metrics: aggregated,
      chart_data: chart_data,
      latency_chart: latency_chart,
      memory_chart: memory_chart
    )}
  end

  defp build_latency_chart(data) do
    points = Enum.map(data, fn point ->
      %{
        "timestamp" => DateTime.to_iso8601(point.timestamp),
        "latency" => get_in(point, ["http.request.duration", :avg]) || 0
      }
    end)

    Vl.new(width: 400, height: 200)
    |> Vl.data_from_values(points)
    |> Vl.mark(:line)
    |> Vl.encode_field(:x, "timestamp", type: :temporal, title: "Time")
    |> Vl.encode_field(:y, "latency", type: :quantitative, title: "Latency (ms)")
    |> Vl.to_spec()
    |> VegaLite.Export.to_html()
  end
end
```

The downside: you're re-rendering the entire chart on every update. For dashboards with many charts updating at 10Hz, this gets expensive.

### Chart.js Hook Approach

A JavaScript hook gives you incremental updates:

```javascript
// assets/js/hooks/chart.js
export const LineChart = {
  mounted() {
    const ctx = this.el.getContext('2d');

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [{
          label: this.el.dataset.label,
          data: [],
          borderColor: this.el.dataset.color || '#3b82f6',
          tension: 0.1,
          fill: false
        }]
      },
      options: {
        responsive: true,
        animation: false,  // Critical for performance
        scales: {
          x: { display: true },
          y: { beginAtZero: true }
        }
      }
    });

    this.handleEvent("chart-update:" + this.el.id, ({points}) => {
      this.chart.data.labels = points.map(p => p.label);
      this.chart.data.datasets[0].data = points.map(p => p.value);
      this.chart.update('none');  // 'none' skips animation
    });
  },

  destroyed() {
    this.chart.destroy();
  }
};
```

The LiveView pushes events rather than re-rendering:

```elixir
def handle_info({:metrics, aggregated}, socket) do
  chart_data = update_chart_data(socket.assigns.chart_data, aggregated)

  points = Enum.map(chart_data, fn point ->
    %{
      label: Calendar.strftime(point.timestamp, "%H:%M:%S"),
      value: get_in(point, ["http.request.duration", :avg]) || 0
    }
  end)

  {:noreply,
    socket
    |> assign(metrics: aggregated, chart_data: chart_data)
    |> push_event("chart-update:latency-chart", %{points: points})}
end
```

The template:

```heex
<canvas id="latency-chart"
        phx-hook="LineChart"
        data-label="Request Latency"
        data-color="#3b82f6">
</canvas>
```

I prefer the hook approach for high-frequency dashboards. The initial setup is more work, but the runtime performance is better.

## Handling High-Frequency Updates

When metrics arrive faster than humans can perceive, you need throttling at multiple layers.

The collector already batches at the ingestion layer. But you might also want client-side throttling for especially busy dashboards:

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  @throttle_ms 250

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "metrics:updates")
    end

    {:ok, assign(socket,
      metrics: %{},
      chart_data: [],
      pending_update: nil,
      last_push: 0
    )}
  end

  def handle_info({:metrics, aggregated}, socket) do
    now = System.monotonic_time(:millisecond)
    time_since_last = now - socket.assigns.last_push

    if time_since_last >= @throttle_ms do
      {:noreply, apply_update(socket, aggregated, now)}
    else
      # Queue the update, schedule a delayed push
      if is_nil(socket.assigns.pending_update) do
        delay = @throttle_ms - time_since_last
        Process.send_after(self(), :flush_pending, delay)
      end
      {:noreply, assign(socket, pending_update: aggregated)}
    end
  end

  def handle_info(:flush_pending, socket) do
    case socket.assigns.pending_update do
      nil -> {:noreply, socket}
      update ->
        now = System.monotonic_time(:millisecond)
        {:noreply, socket |> apply_update(update, now) |> assign(pending_update: nil)}
    end
  end

  defp apply_update(socket, aggregated, now) do
    chart_data = update_chart_data(socket.assigns.chart_data, aggregated)

    socket
    |> assign(metrics: aggregated, chart_data: chart_data, last_push: now)
    |> push_chart_events(chart_data)
  end
end
```

This ensures the client never receives more than 4 updates per second regardless of how fast data arrives.

## Efficient DOM Updates with Streams

For dashboards displaying lists of items—log entries, recent events, active connections—streams are essential. They let LiveView track and update individual items without diffing the entire list.

```elixir
def mount(_params, _session, socket) do
  {:ok, socket |> stream(:events, []) |> assign(event_count: 0)}
end

def handle_info({:new_event, event}, socket) do
  {:noreply,
    socket
    |> stream_insert(:events, event, at: 0, limit: 100)
    |> update(:event_count, &(&1 + 1))}
end
```

The template:

```heex
<div id="events" phx-update="stream">
  <div :for={{dom_id, event} <- @streams.events} id={dom_id} class="event-row">
    <span class="timestamp"><%= event.timestamp %></span>
    <span class="message"><%= event.message %></span>
    <span class={["level", event.level]}><%= event.level %></span>
  </div>
</div>
```

The `limit: 100` keeps memory bounded. Old items are automatically removed from the DOM when new ones push them out.

For metrics that update in place rather than accumulate, `temporary_assigns` reduces memory:

```elixir
def mount(_params, _session, socket) do
  {:ok, assign(socket, metrics: %{}), temporary_assigns: [metrics: %{}]}
end
```

## Putting It Together: A System Metrics Dashboard

Here's a complete example that displays CPU, memory, and request metrics:

```elixir
defmodule MyAppWeb.SystemDashboardLive do
  use MyAppWeb, :live_view

  @refresh_interval 100

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "metrics:updates")
      :timer.send_interval(@refresh_interval, :tick)
    end

    {:ok,
      socket
      |> assign(
        metrics: initial_metrics(),
        history: [],
        connected_at: DateTime.utc_now()
      )
      |> stream(:events, [])}
  end

  def render(assigns) do
    ~H"""
    <div class="dashboard">
      <header class="dashboard-header">
        <h1>System Dashboard</h1>
        <span class="uptime">Connected: <%= format_duration(@connected_at) %></span>
      </header>

      <div class="metrics-grid">
        <.metric_card
          title="Memory"
          value={format_bytes(@metrics.memory_total)}
          subtitle={"Processes: #{format_bytes(@metrics.memory_processes)}"} />

        <.metric_card
          title="Run Queue"
          value={@metrics.run_queue_total}
          subtitle="Schedulers waiting" />

        <.metric_card
          title="Request Rate"
          value={"#{@metrics.requests_per_sec}/s"}
          subtitle={"Avg latency: #{@metrics.avg_latency}ms"} />

        <.metric_card
          title="Error Rate"
          value={"#{Float.round(@metrics.error_rate * 100, 1)}%"}
          subtitle="5xx responses" />
      </div>

      <div class="charts-row">
        <div class="chart-container">
          <h3>Request Latency</h3>
          <canvas id="latency-chart" phx-hook="LineChart"
                  data-label="Latency (ms)" data-color="#3b82f6"></canvas>
        </div>
        <div class="chart-container">
          <h3>Memory Usage</h3>
          <canvas id="memory-chart" phx-hook="LineChart"
                  data-label="Memory (MB)" data-color="#10b981"></canvas>
        </div>
      </div>

      <div class="events-panel">
        <h3>Recent Events</h3>
        <div id="events" phx-update="stream" class="events-list">
          <div :for={{dom_id, event} <- @streams.events} id={dom_id} class="event-row">
            <span class="timestamp"><%= format_time(event.timestamp) %></span>
            <span class={["level", event.level]}><%= event.level %></span>
            <span class="message"><%= event.message %></span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_info({:metrics, raw}, socket) do
    metrics = process_metrics(raw, socket.assigns.metrics)
    history = update_history(socket.assigns.history, metrics)

    {:noreply,
      socket
      |> assign(metrics: metrics, history: history)
      |> push_chart_events(history)}
  end

  def handle_info({:event, event}, socket) do
    {:noreply, stream_insert(socket, :events, event, at: 0, limit: 50)}
  end

  def handle_info(:tick, socket) do
    # Heartbeat for uptime display
    {:noreply, socket}
  end

  defp process_metrics(raw, previous) do
    %{
      memory_total: raw["vm.memory.total"][:avg] || previous.memory_total,
      memory_processes: raw["vm.memory.processes"][:avg] || previous.memory_processes,
      run_queue_total: raw["vm.run_queue.total"][:avg] || previous.run_queue_total,
      requests_per_sec: (raw["http.request.count"][:count] || 0) * 10,
      avg_latency: Float.round(raw["http.request.duration"][:avg] || 0, 1),
      error_rate: calculate_error_rate(raw)
    }
  end

  defp calculate_error_rate(raw) do
    errors = raw["http.status.500"][:count] || 0
    total = raw["http.request.count"][:count] || 1
    errors / total
  end

  defp push_chart_events(socket, history) do
    latency_points = Enum.map(history, fn h ->
      %{label: h.label, value: h.avg_latency}
    end)

    memory_points = Enum.map(history, fn h ->
      %{label: h.label, value: h.memory_total / 1_000_000}
    end)

    socket
    |> push_event("chart-update:latency-chart", %{points: latency_points})
    |> push_event("chart-update:memory-chart", %{points: memory_points})
  end

  defp update_history(history, metrics) do
    point = Map.put(metrics, :label, Calendar.strftime(DateTime.utc_now(), "%H:%M:%S"))
    [point | history] |> Enum.take(60)
  end

  defp initial_metrics do
    %{
      memory_total: 0,
      memory_processes: 0,
      run_queue_total: 0,
      requests_per_sec: 0,
      avg_latency: 0,
      error_rate: 0
    }
  end

  # Helper functions for formatting
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_time(datetime), do: Calendar.strftime(datetime, "%H:%M:%S")

  defp format_duration(started_at) do
    diff = DateTime.diff(DateTime.utc_now(), started_at, :second)
    minutes = div(diff, 60)
    seconds = rem(diff, 60)
    "#{minutes}m #{seconds}s"
  end

  # Component for metric cards
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :subtitle, :string, default: nil

  defp metric_card(assigns) do
    ~H"""
    <div class="metric-card">
      <h4><%= @title %></h4>
      <div class="value"><%= @value %></div>
      <div :if={@subtitle} class="subtitle"><%= @subtitle %></div>
    </div>
    """
  end
end
```

## Performance Considerations

A few things I've learned the hard way:

**Don't subscribe to high-frequency topics directly.** Always have an aggregation layer between raw telemetry and LiveView processes. Each connected client is a process; broadcasting 10,000 events per second to 1,000 clients means 10 million messages.

**Use `push_event` for chart updates.** Re-rendering SVG or canvas elements server-side on every tick is wasteful. Let the client handle incremental updates.

**Bound your history.** It's easy to accidentally accumulate unbounded data in assigns. Always use `Enum.take/2` or equivalent when appending to lists.

**Test with realistic load.** A dashboard that works fine with 10 requests per second will behave very differently at 10,000. Use tools like `k6` or `wrk` to generate realistic traffic during development.

**Consider separate processes for heavy computation.** If you're doing significant aggregation—percentile calculations, for example—offload that to a dedicated GenServer rather than blocking the collector's flush cycle.

Real-time dashboards in LiveView are genuinely enjoyable to build. The mental model is clean: data flows from telemetry through PubSub to processes that render HTML. No JavaScript state management, no WebSocket protocols to debug, no eventual consistency headaches. Just processes sending messages.

The BEAM was built for this kind of work.

---

**Fact-check notes:**
- Telemetry event names for Phoenix and Ecto should be verified against current library versions
- Chart.js API may have changed; verify the `update('none')` syntax works with your version
- VegaLite export API should be verified against the current `vega_lite` hex package
