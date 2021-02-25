defmodule Amgr.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      AmgrWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Amgr.PubSub},
      # Start the Endpoint (http/https)
      AmgrWeb.Presence,
      AmgrWeb.Endpoint
      # Start a worker by calling: Amgr.Worker.start_link(arg)
      # {Amgr.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Amgr.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AmgrWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
