defmodule Amgr.MixProject do
  use Mix.Project

  def project do
    [
      app: :amgr,
      version: File.read!("VERSION") |> String.trim(),
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      mod: {Amgr.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.0"},
      {:earmark,
       github: "dbernheisel/earmark", branch: "db-inline-code-smartypants", override: true},
      {:makeup_elixir, ">= 0.0.0"},
      {:nimble_publisher, "~> 0.1.0"},
      {:phoenix, "~> 1.5.4"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_dashboard, "~> 0.2"},
      {:phoenix_live_view, "~> 0.15"},
      {:plug_cowboy, "~> 2.0"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:timex, "~> 3.6"},
      {:redirect, "~> 0.3.0"},
      # Test
      {:floki, ">= 0.0.0", only: :test},
      {:finch, "~> 0.3", only: :test},
      {:excoveralls, "~> 0.12", only: :test},
      {:sobelow, "~> 0.8", only: :dev},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      # Dev
      {:phoenix_live_reload, "~> 1.2", only: :dev}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd yarn --cwd ./assets install"],
      check: ["format --check-formatted", "sobelow -i Config.HTTPS", "credo"],
    ]
  end
end
