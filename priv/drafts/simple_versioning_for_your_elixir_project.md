%{
title: "Simple versioning for your Elixir project",
category: "programming",
tags: ["elixir", "programming"],
description: "Simple versioning for your Elixir project with no fuzz",
published: true
}

---

Your version number lives in one place or it lies.

That sounds dramatic, but I have lost count of how many projects I have seen where the version in `mix.exs` says one thing, the Docker image tag says another, and the health check endpoint returns a third. It happens gradually. Someone bumps the version in mix.exs but forgets the Dockerfile `LABEL`. Someone else hardcodes a string in the `/health` response. Six months later, nobody trusts any of them.

There is a simpler way. One file. One source of truth. Everything else reads from it.

## The VERSION File

Create a file called `VERSION` at the root of your project. Put a semver string in it and nothing else:

```
0.3.0
```

No comments. No metadata. Just the version. This file is trivially readable by any tool in any language — shell scripts, CI pipelines, Docker builds, and yes, your `mix.exs`.

## Wiring It Into mix.exs

The integration is a single private function:

```elixir
defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      version: version(),
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp version do
    "VERSION"
    |> File.read!()
    |> String.trim()
  end

  # ...
end
```

That is the entire change. `File.read!/1` runs at compile time when Mix evaluates your project definition. The `String.trim/1` strips the trailing newline that most editors add. If the VERSION file is missing, the build fails immediately with a clear error. No silent defaults. No fallbacks. Fail loud.

This is not a novel pattern. The `castore` library — one of the most downloaded packages on Hex — uses exactly this approach. When established libraries in the ecosystem converge on a pattern, that is a signal worth paying attention to.

## Automating Version Bumps

Editing a file by hand is simple enough, but humans are bad at repetitive tasks. A lightweight Mix task handles the three standard bump types:

```elixir
defmodule Mix.Tasks.Version.Bump do
  @moduledoc "Bump the project version. Usage: mix version.bump [major|minor|patch]"
  @shortdoc "Bump the project version"

  use Mix.Task

  @impl Mix.Task
  def run([segment]) when segment in ~w(major minor patch) do
    current = read_version()
    next = bump(current, String.to_atom(segment))

    File.write!("VERSION", "#{next}\n")
    Mix.shell().info("Version bumped: #{current} -> #{next}")
  end

  def run(_), do: Mix.shell().error("Usage: mix version.bump [major|minor|patch]")

  defp read_version do
    "VERSION"
    |> File.read!()
    |> String.trim()
    |> Version.parse!()
  end

  defp bump(%Version{major: major}, :major), do: "#{major + 1}.0.0"
  defp bump(%Version{major: major, minor: minor}, :minor), do: "#{major}.#{minor + 1}.0"
  defp bump(%Version{major: major, minor: minor, patch: patch}, :patch),
    do: "#{major}.#{minor}.#{patch + 1}"
end
```

Drop that into `lib/mix/tasks/version_bump.ex` and you get:

```bash
$ mix version.bump patch
Version bumped: 0.3.0 -> 0.3.1

$ mix version.bump minor
Version bumped: 0.3.1 -> 0.4.0

$ mix version.bump major
Version bumped: 0.4.0 -> 1.0.0
```

Elixir's built-in `Version` module does the parsing and validation. No dependencies. No configuration files. Under 30 lines of code.

If you prefer shell scripts over Mix tasks, the equivalent is even shorter:

```bash
#!/usr/bin/env bash
# scripts/bump_version.sh
set -euo pipefail

VERSION=$(cat VERSION | tr -d '[:space:]')
IFS='.' read -r major minor patch <<< "$VERSION"

case "${1:-patch}" in
  major) echo "$((major + 1)).0.0" > VERSION ;;
  minor) echo "${major}.$((minor + 1)).0" > VERSION ;;
  patch) echo "${major}.${minor}.$((patch + 1))" > VERSION ;;
  *) echo "Usage: $0 [major|minor|patch]" && exit 1 ;;
esac

echo "$(cat VERSION | tr -d '[:space:]')"
```

Either approach works. I prefer the Mix task because it stays inside the ecosystem and is discoverable via `mix help`.

## Git Tagging Strategy

A version bump without a git tag is half the job. Tags give you a point-in-time reference that tools like GitHub Releases, deployment scripts, and `git describe` can hook into.

The workflow is mechanical:

```bash
# Bump the version
mix version.bump minor

# Commit the change
git add VERSION
git commit -m "Bump version to $(cat VERSION)"

# Tag it
git tag -a "v$(cat VERSION | tr -d '[:space:]')" -m "Release $(cat VERSION | tr -d '[:space:]')"

# Push both
git push origin main --tags
```

You can collapse this into a single script or a Makefile target. The point is that the VERSION file drives everything. The git tag is derived from it, not the other way around.

A few conventions worth following:

- **Prefix tags with `v`**. It is the overwhelmingly common convention in Elixir and Erlang projects. `v0.3.0`, not `0.3.0`.
- **Use annotated tags** (`-a`), not lightweight tags. Annotated tags store the tagger, date, and message. They are proper Git objects. Lightweight tags are just pointers.
- **Tag after the version commit**, not before. The tag should point at the commit that contains the new version string. This sounds obvious, but I have seen the reverse.

## Exposing the Version at Runtime

Your application knows its own version. The OTP runtime stores it. You just need to ask:

```elixir
# Returns a charlist like ~c"0.3.0"
{:ok, vsn} = :application.get_key(:my_app, :vsn)
version = to_string(vsn)
```

Or the more idiomatic Elixir wrapper:

```elixir
Application.spec(:my_app, :vsn) |> to_string()
```

This works in any process at any time after your application has started. It reads from the compiled application spec, so there is zero file I/O at runtime.

### Health Check Endpoint

For Phoenix applications, a health check endpoint that includes the version is trivially useful for deployment verification. Add a route:

```elixir
# In your router
scope "/api", MyAppWeb do
  pipe_through :api
  get "/health", HealthController, :index
end
```

And a minimal controller:

```elixir
defmodule MyAppWeb.HealthController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    version = Application.spec(:my_app, :vsn) |> to_string()

    json(conn, %{
      status: "ok",
      version: version
    })
  end
end
```

Now `curl https://yourapp.com/api/health` returns:

```json
{"status": "ok", "version": "0.3.0"}
```

After every deploy, you can verify the running version matches what you intended to ship. When it does not match, you know immediately instead of debugging phantom issues for an hour.

## Why Not Just Hardcode It?

The obvious counter-argument: the version string in `mix.exs` is already right there. Why add a file?

For a library you publish to Hex and never reference elsewhere, hardcoding is fine. It is one value in one place.

But the moment your version appears in more than one context — Docker tags, CI artifact names, health endpoints, Sentry release tracking, deployment notifications — you have a choice. Either every one of those contexts reads from the same source, or you maintain parallel copies and hope they stay in sync.

They will not stay in sync. I have never seen a project where manually synchronized version strings stayed correct for more than a few months. The VERSION file eliminates the category of bug entirely.

The cost is one file with one line in it. The return is a single source of truth that composes with every tool in your pipeline.

## The Whole Picture

Here is what the approach looks like end to end:

```
VERSION                    # "0.3.0" — the single source of truth
  |
  +---> mix.exs            # version() reads from VERSION at compile time
  |
  +---> git tag            # v0.3.0, derived from VERSION
  |
  +---> Application.spec   # runtime access, compiled into the .app file
  |
  +---> /api/health        # serves version to monitoring tools
  |
  +---> Dockerfile         # COPY VERSION . -> reads it during build
  |
  +---> CI pipeline         # cat VERSION -> uses it for artifact naming
```

Every downstream consumer reads from the same origin. Change it in one place, and the change propagates everywhere. That is not cleverness. That is basic engineering hygiene.

The best infrastructure is the kind you set up once and never think about again. A VERSION file is exactly that — small enough to be boring, reliable enough to be trustworthy.