%{
title: "Observability for Elixir Applications",
category: "Programming",
tags: ["elixir", "observability", "telemetry", "opentelemetry", "monitoring"],
description: "OpenTelemetry integration, distributed tracing, and structured logging",
published: false
}
---

# Observability for Elixir Applications

You cannot debug what you cannot see. This sounds obvious until you watch a team spend three days hunting a performance regression that would have taken three minutes to identify with proper instrumentation.

Observability is not monitoring. Monitoring tells you when something is wrong. Observability tells you why. In a distributed Elixir system — where dozens of processes handle a single request, where failures are routine and recovery is automatic — understanding the "why" requires a fundamentally different approach than tailing log files and watching CPU graphs.

## The Three Pillars: Logs, Metrics, Traces

The observability community has converged on three complementary data types, each answering different questions about your system.

**Logs** are discrete events with context. "User 42 failed authentication at 14:32:07 because their password hash did not match." Logs answer: what happened? They are high-cardinality (each event is unique) and high-context (they carry arbitrary metadata). They are also expensive to store and query at scale.

**Metrics** are aggregated measurements over time. "Authentication failures averaged 12 per minute over the last hour." Metrics answer: how much? They are low-cardinality (you aggregate many events into summary statistics) and cheap to store. But they lose the individual context — you know failures increased, not why.

**Traces** are causality chains across service boundaries. "Request ABC started in the API gateway, called the auth service, which queried the database, which timed out." Traces answer: how did we get here? They connect the dots across process and network boundaries.

Elixir's ecosystem has first-class support for all three. The foundation is Telemetry.

## Telemetry: The Backbone of Elixir Instrumentation

Telemetry is a lightweight library for dynamic dispatching of events. Libraries emit events; your application attaches handlers to process them. This decoupling is critical — library authors do not need to know which observability backend you use.

A Telemetry event has three components:

```elixir
:telemetry.execute(
  [:my_app, :request, :complete],  # Event name (list of atoms)
  %{duration: 42_000_000},         # Measurements (numeric values)
  %{route: "/users", status: 200}  # Metadata (arbitrary context)
)
```

The event name is a hierarchical identifier. By convention, the first element is your application or library name. Measurements are the numeric data you care about — durations, counts, sizes. Metadata is everything else — request IDs, user IDs, route names, error types.

### Attaching Handlers

You attach handlers at application startup, typically in your Application module:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Attach telemetry handlers before starting supervision tree
    attach_telemetry_handlers()

    children = [
      MyApp.Repo,
      MyAppWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp attach_telemetry_handlers do
    :telemetry.attach_many(
      "my-app-handlers",
      [
        [:my_app, :request, :complete],
        [:my_app, :request, :exception],
        [:phoenix, :endpoint, :stop],
        [:ecto, :repo, :query]
      ],
      &MyApp.TelemetryHandler.handle_event/4,
      nil
    )
  end
end
```

The handler function receives four arguments: the event name, measurements, metadata, and your handler config (the fourth argument to `attach_many`).

```elixir
defmodule MyApp.TelemetryHandler do
  require Logger

  def handle_event([:my_app, :request, :complete], measurements, metadata, _config) do
    Logger.info("Request completed",
      duration_ms: System.convert_time_unit(measurements.duration, :native, :millisecond),
      route: metadata.route,
      status: metadata.status
    )
  end

  def handle_event([:ecto, :repo, :query], measurements, metadata, _config) do
    if measurements.total_time > 100_000_000 do  # 100ms in native units
      Logger.warning("Slow query detected",
        query: metadata.query,
        duration_ms: System.convert_time_unit(measurements.total_time, :native, :millisecond),
        source: metadata.source
      )
    end
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
```

One critical detail: Telemetry handlers run in the calling process. If your handler crashes, it takes down the process that emitted the event. If your handler blocks, it blocks that process. Keep handlers fast and defensive.

### What Phoenix and Ecto Already Emit

You get substantial instrumentation for free. Phoenix emits events for every request:

- `[:phoenix, :endpoint, :start]` — request received
- `[:phoenix, :endpoint, :stop]` — response sent
- `[:phoenix, :router_dispatch, :start]` — routing began
- `[:phoenix, :router_dispatch, :stop]` — controller invoked

Ecto emits events for every query:

- `[:my_app, :repo, :query]` — query executed (includes query string, params, timing)

LiveView, Oban, Broadway, Finch — most major Elixir libraries follow this pattern. Consult their documentation for the specific events they emit.

## OpenTelemetry: The Industry Standard

Telemetry is Elixir-specific. OpenTelemetry is a vendor-neutral standard for telemetry data across languages and platforms. If you run a polyglot architecture, or want to use commercial observability platforms, OpenTelemetry is the integration point.

The Elixir OpenTelemetry ecosystem consists of several packages:

```elixir
# mix.exs
defp deps do
  [
    {:opentelemetry, "~> 1.4"},
    {:opentelemetry_api, "~> 1.3"},
    {:opentelemetry_exporter, "~> 1.7"},
    {:opentelemetry_phoenix, "~> 1.2"},
    {:opentelemetry_ecto, "~> 1.2"},
    {:opentelemetry_oban, "~> 1.1"}  # if using Oban
  ]
end
```

Configuration happens in your config files:

```elixir
# config/runtime.exs
config :opentelemetry,
  resource: [
    service: [
      name: "my-app",
      version: Application.spec(:my_app, :vsn) |> to_string()
    ]
  ],
  span_processor: :batch,
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
```

The library packages (`opentelemetry_phoenix`, `opentelemetry_ecto`) automatically translate Telemetry events into OpenTelemetry spans. You set them up at application start:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    OpentelemetryPhoenix.setup()
    OpentelemetryEcto.setup([:my_app, :repo])

    children = [
      MyApp.Repo,
      MyAppWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

That is the minimal setup. Every Phoenix request and Ecto query now generates spans that flow to your configured exporter.

## Distributed Tracing Across Services

The power of tracing emerges in distributed systems. When service A calls service B, the trace context must propagate. Otherwise, you see two disconnected traces instead of one coherent story.

OpenTelemetry handles this through context propagation. When making HTTP requests with a client that supports OpenTelemetry (like Finch with the appropriate middleware), trace headers are automatically injected:

```elixir
defmodule MyApp.ExternalService do
  require OpenTelemetry.Tracer, as: Tracer

  def fetch_user_data(user_id) do
    Tracer.with_span "external_service.fetch_user" do
      Tracer.set_attributes([
        {:user_id, user_id},
        {:service, "user-service"}
      ])

      url = "https://user-service.internal/users/#{user_id}"

      case Finch.build(:get, url) |> Finch.request(MyApp.Finch) do
        {:ok, %{status: 200, body: body}} ->
          Tracer.set_attribute(:status, "success")
          {:ok, Jason.decode!(body)}

        {:ok, %{status: status}} ->
          Tracer.set_attribute(:status, "error")
          Tracer.set_attribute(:http_status, status)
          {:error, :unexpected_status}

        {:error, reason} ->
          Tracer.record_exception(reason)
          {:error, reason}
      end
    end
  end
end
```

For manual context propagation (when not using auto-instrumented HTTP clients), you extract and inject the context explicitly:

```elixir
# Extracting context from incoming request headers
def handle_incoming_request(headers) do
  :otel_propagator_text_map.extract(headers)
  # Context is now set for this process
end

# Injecting context into outgoing request headers
def make_outgoing_request(url, body) do
  headers = :otel_propagator_text_map.inject([])
  # headers now contains trace context
  HTTPClient.post(url, body, headers)
end
```

## Structured Logging with Logger Metadata

Elixir's Logger supports metadata — key-value pairs attached to log messages. Combined with a structured logging backend, this transforms logs from opaque strings into queryable data.

Set metadata at process boundaries:

```elixir
defmodule MyAppWeb.Plugs.RequestContext do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    request_id = get_req_header(conn, "x-request-id") |> List.first() || generate_request_id()

    Logger.metadata(
      request_id: request_id,
      user_id: conn.assigns[:current_user][:id],
      remote_ip: conn.remote_ip |> :inet.ntoa() |> to_string()
    )

    conn
  end

  defp generate_request_id, do: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
end
```

Every log statement in that process now carries this metadata. In a GenServer handling background work:

```elixir
defmodule MyApp.JobWorker do
  use GenServer
  require Logger

  def handle_cast({:process, job}, state) do
    Logger.metadata(job_id: job.id, job_type: job.type)

    Logger.info("Starting job processing")

    case process_job(job) do
      {:ok, result} ->
        Logger.info("Job completed successfully", result_size: byte_size(result))
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Job failed", reason: inspect(reason))
        {:noreply, state}
    end
  end
end
```

For JSON-formatted logs (required by most log aggregation systems), configure a backend like `logger_json`:

```elixir
# config/prod.exs
config :logger, :console,
  format: {LoggerJSON.Formatters.GoogleCloud, :format},
  metadata: :all
```

Now your logs are machine-parseable. You can query for all logs where `job_type = "invoice_generation"` and `duration > 5000`.

## Building Custom Telemetry Reporters

Sometimes you need metrics that do not fit the pre-built integrations. Building a custom reporter involves three steps: defining the metrics, attaching to events, and periodically reporting.

Here is a complete example using `telemetry_metrics` and a custom reporter:

```elixir
defmodule MyApp.Metrics do
  import Telemetry.Metrics

  def metrics do
    [
      # Counters: count occurrences
      counter("phoenix.endpoint.stop.duration",
        tags: [:route, :status],
        tag_values: &tag_values/1
      ),

      # Distributions: track value distributions (for percentiles)
      distribution("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        tags: [:route],
        tag_values: &tag_values/1,
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000]]
      ),

      # Summaries: track statistics
      summary("ecto.repo.query.total_time",
        unit: {:native, :millisecond},
        tags: [:source]
      ),

      # Last value: track current state
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total")
    ]
  end

  defp tag_values(%{conn: conn}) do
    %{
      route: Phoenix.Controller.controller_module(conn),
      status: conn.status
    }
  end
end
```

For a custom console reporter (useful for development):

```elixir
defmodule MyApp.Metrics.ConsoleReporter do
  use GenServer
  require Logger

  def start_link(opts) do
    metrics = Keyword.fetch!(opts, :metrics)
    GenServer.start_link(__MODULE__, metrics, name: __MODULE__)
  end

  @impl true
  def init(metrics) do
    groups = Enum.group_by(metrics, & &1.event_name)

    for {event, metrics} <- groups do
      :telemetry.attach(
        {__MODULE__, event, self()},
        event,
        &__MODULE__.handle_event/4,
        metrics
      )
    end

    {:ok, %{}}
  end

  def handle_event(event_name, measurements, metadata, metrics) do
    for metric <- metrics do
      measurement = extract_measurement(metric, measurements)
      tags = extract_tags(metric, metadata)

      Logger.debug("Metric: #{inspect(metric.name)}",
        value: measurement,
        tags: tags
      )
    end
  end

  defp extract_measurement(metric, measurements) do
    case metric.measurement do
      fun when is_function(fun) -> fun.(measurements)
      key -> Map.get(measurements, key)
    end
  end

  defp extract_tags(metric, metadata) do
    tag_values = metric.tag_values.(metadata)
    Map.take(tag_values, metric.tags)
  end
end
```

## Connecting to Observability Backends

Different backends have different integration patterns. Here are working configurations for the major platforms.

### Prometheus

Prometheus uses a pull model — it scrapes a metrics endpoint you expose.

```elixir
# mix.exs
{:telemetry_metrics_prometheus, "~> 1.1"}

# application.ex
children = [
  {TelemetryMetricsPrometheus, metrics: MyApp.Metrics.metrics()}
]

# router.ex
forward "/metrics", TelemetryMetricsPrometheus
```

Prometheus will scrape `http://your-app:4000/metrics` and ingest the data.

### Datadog

Datadog accepts metrics via StatsD protocol or their agent:

```elixir
# mix.exs
{:telemetry_metrics_statsd, "~> 0.7"}

# application.ex
children = [
  {TelemetryMetricsStatsd,
    metrics: MyApp.Metrics.metrics(),
    host: "localhost",
    port: 8125,
    formatter: :datadog}
]
```

For traces, configure the OpenTelemetry exporter to send to Datadog's OTLP endpoint, or use the Datadog agent as a collector.

### Honeycomb

Honeycomb ingests OpenTelemetry data natively:

```elixir
# config/runtime.exs
config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "https://api.honeycomb.io:443",
  otlp_headers: [
    {"x-honeycomb-team", System.fetch_env!("HONEYCOMB_API_KEY")}
  ]
```

Honeycomb excels at high-cardinality data. Unlike Prometheus (which struggles with many unique tag values), Honeycomb handles arbitrary metadata without pre-aggregation. This makes it particularly well-suited to Elixir's process-heavy architecture, where you might want to query by individual process IDs.

### Self-Hosted: Grafana Stack

For self-hosted observability, the Grafana stack (Prometheus, Loki, Tempo) provides a complete solution:

```elixir
# Metrics to Prometheus (as shown above)
# Traces to Tempo via OTLP
config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://tempo:4317"

# Logs to Loki via logger backend
config :logger,
  backends: [LokiLoggerBackend]

config :loki_logger_backend,
  url: "http://loki:3100/loki/api/v1/push",
  labels: %{app: "my_app", env: "production"}
```

## Practical Patterns

A few patterns I have found valuable in production Elixir systems:

**Correlation IDs everywhere.** Generate a unique ID at the edge of your system and propagate it through every process, log statement, and external call. When something goes wrong, you can reconstruct the entire request flow.

**Sample expensive operations.** Tracing every request in a high-throughput system generates enormous data volumes. Configure sampling:

```elixir
config :opentelemetry,
  sampler: {:parent_based, %{root: {:trace_id_ratio_based, 0.1}}}
```

This samples 10% of traces. Adjust based on your traffic and budget.

**Measure what matters.** Instrument business metrics, not just technical ones. "Orders processed per minute" tells you more than "requests per minute." "Payment failures by reason" tells you more than "HTTP 500s."

**Alert on symptoms, debug with causes.** Your alerting should fire on user-facing symptoms: elevated error rates, increased latency, failed transactions. Your observability stack helps you debug the cause once the alert fires.

## Conclusion

Observability in Elixir is not a bolt-on afterthought. The Telemetry library, the OpenTelemetry integrations, and the structured logging support in Logger form a coherent system designed from the ground up.

The investment compounds. Every hour you spend on instrumentation saves days of debugging later. Every span you add to a trace is context you do not have to reconstruct from memory during an incident. Every structured log field is a query you can run instead of a grep you have to write.

Instrument early. Instrument intentionally. Your future self, paged at 3 AM, will thank you.

---

**Claims to verify:**
- OpenTelemetry package versions should be verified against current Hex.pm listings as they update frequently
- Specific Honeycomb and Datadog configuration options may have changed — consult their current documentation
- Prometheus scraping configuration depends on your infrastructure setup
- Sampling ratios and bucket values in examples are illustrative — tune them for your specific workload
- The `logger_json` and `loki_logger_backend` packages should be verified for current compatibility with your Elixir/OTP version
