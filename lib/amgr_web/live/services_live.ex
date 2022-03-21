defmodule AmgrWeb.Live.Services do
  @moduledoc false
  use AmgrWeb, :live_view

  def mount(_params, _session, socket) do
    services = :persistent_term.get(:services)
    {:ok, socket |> assign(:services, services)}
  end
end
