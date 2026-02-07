%{
title: "Deploying Elixir with Kamal 2",
category: "Programming",
tags: ["elixir", "deployment", "kamal", "docker", "devops"],
description: "Zero-downtime deployments, secrets management, and self-hosted Elixir apps",
published: false
}

---

Kubernetes is overkill for most applications. I have watched teams spend months building deployment pipelines that could have been replaced by a single SSH command and a process manager. The industry's obsession with container orchestration has created a generation of developers who cannot deploy a web application without a YAML file longer than their actual code.

Kamal changes this calculus entirely.

DHH and the Rails team built Kamal to solve a specific problem: deploying containerized applications to bare metal or simple VPS instances without the operational overhead of Kubernetes. It handles the parts that matter, like zero-downtime deployments, health checks, and rolling updates, while ignoring the parts that don't, like service meshes and custom resource definitions.

For Elixir applications, Kamal is particularly compelling. The BEAM already handles most of what you would use Kubernetes for. Process supervision, fault tolerance, load distribution across cores. You do not need an orchestrator to restart crashed containers when your runtime restarts crashed processes automatically.

## What Kamal Actually Does

Kamal is a deployment tool written in Ruby that uses Docker and SSH to deploy your application to one or more servers. It runs a reverse proxy called Kamal Proxy on each host, manages container lifecycle, handles health checks, and coordinates zero-downtime deployments.

The architecture is straightforward. Your application runs in a Docker container. Kamal Proxy sits in front of it, routing traffic and performing health checks. When you deploy, Kamal builds a new container, starts it alongside the old one, waits for health checks to pass, switches traffic, and stops the old container.

No etcd. No control plane. No operators. Just containers, a proxy, and SSH.

Version 2 introduced significant changes from version 1. The proxy is now Kamal Proxy instead of Traefik. Configuration moved from environment variables to a cleaner YAML structure. Boot strategies, health check configurations, and secret management all received overhauls.

## Setting Up Kamal for Phoenix

Start by installing Kamal. It is a Ruby gem:

```bash
gem install kamal
```

Or if you prefer to keep Ruby dependencies isolated, use Docker:

```bash
docker run -it --rm -v "$PWD:/workdir" -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent ghcr.io/basecamp/kamal:latest init
```

Initialize Kamal in your Phoenix project:

```bash
kamal init
```

This creates two files: `config/deploy.yml` and `.kamal/secrets`. The deploy configuration is where the real work happens.

Here is a production-ready configuration for a Phoenix application:

```yaml
# config/deploy.yml
service: myapp

image: registry.example.com/myapp

servers:
  web:
    hosts:
      - 192.168.1.10
      - 192.168.1.11
    labels:
      kamal-proxy.http_request_timeout: 60

proxy:
  ssl: true
  host: myapp.example.com
  healthcheck:
    interval: 3
    path: /health
    timeout: 3

registry:
  server: registry.example.com
  username: deploy
  password:
    - KAMAL_REGISTRY_PASSWORD

builder:
  multiarch: false
  args:
    MIX_ENV: prod

env:
  clear:
    PHX_HOST: myapp.example.com
    PORT: 4000
  secret:
    - DATABASE_URL
    - SECRET_KEY_BASE
    - PHX_SERVER

ssh:
  user: deploy

accessories:
  db:
    image: postgres:16
    host: 192.168.1.10
    port: 5432
    env:
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data
```

The `servers` section defines where your application runs. You can have multiple server roles. For a typical Phoenix app, you might separate web servers from background job workers:

```yaml
servers:
  web:
    hosts:
      - 192.168.1.10
      - 192.168.1.11
  worker:
    hosts:
      - 192.168.1.12
    cmd: bin/myapp eval "MyApp.Worker.start()"
```

Each role can have different commands, labels, and resource configurations.

## Docker Configuration for Elixir Releases

Phoenix ships with a production-ready Dockerfile since version 1.6.3. It uses multi-stage builds to create minimal release images. Here is what the generated Dockerfile looks like with annotations:

```dockerfile
# Build stage: compile the release
ARG ELIXIR_VERSION=1.16.0
ARG OTP_VERSION=26.2.1
ARG DEBIAN_VERSION=bookworm-20240130-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Copy runtime config
COPY config/runtime.exs config/

# Build the release
COPY rel rel
RUN mix release

# Runtime stage: minimal image for running the release
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

# Copy the release from builder
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/myapp ./

USER nobody

# Set runtime environment
ENV HOME=/app
ENV MIX_ENV="prod"
ENV PHX_SERVER="true"

CMD ["/app/bin/server"]
```

The key points: multi-stage build keeps the final image small. The release bundles the BEAM, so you do not need Erlang or Elixir installed at runtime. The `nobody` user runs the application without root privileges.

One modification I always make is adding a health check endpoint. Create a simple plug:

```elixir
# lib/myapp_web/plugs/health_check.ex
defmodule MyAppWeb.Plugs.HealthCheck do
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/health"} = conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
```

Add it to your endpoint before the router:

```elixir
# lib/myapp_web/endpoint.ex
plug MyAppWeb.Plugs.HealthCheck
plug MyAppWeb.Router
```

This gives Kamal Proxy something to check before routing traffic to a new container.

## Zero-Downtime Deployments

Kamal achieves zero-downtime deployments through a choreographed sequence. When you run `kamal deploy`, here is what happens:

1. Build the Docker image locally or on a remote builder
2. Push the image to your registry
3. Pull the image on each server
4. Start the new container with a different internal port
5. Wait for health checks to pass
6. Tell Kamal Proxy to route traffic to the new container
7. Stop the old container
8. Remove the old container

The health check configuration in `deploy.yml` controls step 5:

```yaml
proxy:
  healthcheck:
    interval: 3       # Check every 3 seconds
    path: /health     # Hit this endpoint
    timeout: 3        # Wait up to 3 seconds for response
```

Kamal Proxy will attempt health checks repeatedly until the container responds with a 2xx status code. If the container never becomes healthy, the deployment fails and the old container keeps running.

For Elixir applications, I configure the health check to verify more than just "the server is running." Here is a more thorough health check:

```elixir
defmodule MyAppWeb.Plugs.HealthCheck do
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/health"} = conn, _opts) do
    checks = [
      {:database, check_database()},
      {:migrations, check_migrations()}
    ]

    case Enum.filter(checks, fn {_, status} -> status != :ok end) do
      [] ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{status: "healthy", checks: %{}}))
        |> halt()

      failures ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{
          status: "unhealthy",
          failures: Map.new(failures)
        }))
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp check_database do
    case Ecto.Adapters.SQL.query(MyApp.Repo, "SELECT 1", []) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp check_migrations do
    case Ecto.Migrator.migrations(MyApp.Repo) do
      [] -> :ok
      pending when is_list(pending) -> :ok
      _ -> {:error, "migration check failed"}
    end
  end
end
```

This ensures your container does not receive traffic until it can actually serve requests.

## Secrets Management

Kamal 2 introduced a cleaner secrets management approach. Create `.kamal/secrets` with your sensitive values:

```bash
# .kamal/secrets
KAMAL_REGISTRY_PASSWORD=your-registry-password
DATABASE_URL=postgres://user:pass@db.example.com:5432/myapp_prod
SECRET_KEY_BASE=your-secret-key-base-here
PHX_SERVER=true
POSTGRES_PASSWORD=postgres-password
```

Add this file to `.gitignore`. Do not commit it.

Reference secrets in `deploy.yml` using the `secret` key under `env`:

```yaml
env:
  clear:
    PHX_HOST: myapp.example.com
    PORT: 4000
  secret:
    - DATABASE_URL
    - SECRET_KEY_BASE
```

For team environments, Kamal supports secret backends. You can pull secrets from 1Password, AWS Secrets Manager, or other providers:

```yaml
# Using 1Password
env:
  secret:
    - DATABASE_URL
    - SECRET_KEY_BASE

secrets:
  - KAMAL_REGISTRY_PASSWORD
  - DATABASE_URL
  - SECRET_KEY_BASE

secrets:
  provider: 1password
```

The secrets are injected as environment variables when your container starts. Your `config/runtime.exs` reads them as usual:

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL environment variable is not set"

  config :myapp, MyApp.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE environment variable is not set"

  config :myapp, MyAppWeb.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT") || "4000")],
    secret_key_base: secret_key_base,
    server: System.get_env("PHX_SERVER") == "true"
end
```

## Rolling Updates and Rollbacks

By default, Kamal deploys to all servers simultaneously. For larger deployments, you want rolling updates:

```yaml
servers:
  web:
    hosts:
      - 192.168.1.10
      - 192.168.1.11
      - 192.168.1.12
      - 192.168.1.13

boot:
  limit: 2           # Deploy to 2 servers at a time
  wait: 10           # Wait 10 seconds between batches
```

This deploys to two servers, waits for health checks, waits another 10 seconds, then deploys to the next two. If any batch fails, the deployment stops.

Rollbacks are straightforward. Kamal tracks your recent images:

```bash
# See available versions
kamal app images

# Roll back to previous version
kamal rollback
```

For more control, specify a version:

```bash
kamal rollback [VERSION]
```

The rollback follows the same zero-downtime process. Start new containers with the old image, health check, switch traffic, stop current containers.

## Running Migrations

Elixir releases support running one-off commands. For migrations, add this to your release configuration:

```elixir
# rel/overlays/bin/migrate
#!/bin/sh
cd -P -- "$(dirname -- "$0")"
exec ./myapp eval "MyApp.Release.migrate()"
```

And the corresponding module:

```elixir
# lib/myapp/release.ex
defmodule MyApp.Release do
  @app :myapp

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

Run migrations before deployment:

```bash
kamal app exec --reuse "bin/migrate"
```

Or add a deploy hook:

```yaml
# config/deploy.yml
hooks:
  pre-deploy:
    cmd: bin/migrate
```

## Kamal vs Fly.io vs Gigalixir

Three legitimate options for deploying Elixir applications. Each makes different tradeoffs.

**Fly.io** runs your containers on their global edge network. You get geographic distribution, automatic TLS, and a managed Postgres option. The free tier is generous. The downside: you are locked into their platform. Pricing can surprise you at scale. And their Elixir clustering story, while improved, requires their specific networking setup.

**Gigalixir** is purpose-built for Elixir. It understands releases, handles clustering automatically, and offers a Heroku-like experience. The platform manages more for you. The downside: less control over infrastructure, higher costs at scale, and another platform to depend on.

**Kamal** gives you control. You own the servers. You see what is running. You can SSH in and debug. The downside: you manage the servers. Security patches, disk space, networking are your responsibility.

Here is how I decide:

- Side project or startup validating an idea: Fly.io. Speed to deploy matters more than cost optimization.
- Elixir-specific needs like distributed clustering with libcluster: Gigalixir or self-managed.
- Production application where you need full control: Kamal.
- Existing infrastructure or compliance requirements: Kamal.

Cost comparison at 2 servers with 4GB RAM each:

| Platform | Approximate Monthly Cost |
|----------|--------------------------|
| Fly.io | $60-80 |
| Gigalixir | $75-100 |
| Kamal + Hetzner | $15-25 |
| Kamal + DigitalOcean | $50-70 |

The Hetzner numbers are not a typo. European VPS providers offer remarkable value. Kamal does not care where your servers live.

## Production Checklist

Before deploying with Kamal, verify:

1. **Secrets are not in git.** Check `.gitignore` includes `.kamal/secrets`.
2. **Health check endpoint exists.** Kamal Proxy needs something to hit.
3. **Runtime configuration reads from environment.** Use `config/runtime.exs`.
4. **Migrations can run.** Test `bin/migrate` locally in a release.
5. **SSH access works.** Run `kamal server bootstrap` first.
6. **Registry authentication works.** Test `docker login` with your credentials.
7. **Firewall allows ports 80 and 443.** Kamal Proxy needs these.
8. **Server has Docker installed.** Kamal can do this with `kamal server bootstrap`.

Run through a deployment to a staging environment first. Kamal is straightforward, but catching configuration issues in staging beats catching them in production.

## The Operational Reality

I have been running Elixir applications with Kamal for production workloads, and the experience is exactly what I hoped for: boring. Deployments work. Rollbacks work. Health checks catch bad releases before they take traffic.

The BEAM's operational characteristics complement Kamal well. Hot code upgrades are elegant in theory but terrifying in practice. With Kamal, I get the pragmatic version: new container, health check, traffic switch, old container gone. The result is the same. The process is debuggable.

Kubernetes solves problems you probably do not have. Kamal solves problems you definitely do.

---

**Claims to verify:**

- Kamal 2 uses Kamal Proxy instead of Traefik (accurate as of Kamal 2.0 release)
- Phoenix includes production Dockerfile since version 1.6.3
- Cost estimates for Fly.io, Gigalixir, and VPS providers are approximate and should be verified against current pricing
- The default health check interval and timeout values in Kamal Proxy configuration
