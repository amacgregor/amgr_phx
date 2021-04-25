defmodule AmgrWeb.Live.Publications do
  @moduledoc false
  use AmgrWeb, :live_view

  def mount(_params, _session, socket) do
    publications = :persistent_term.get(:publications)
    {:ok, socket |> assign(:publications, publications)}
  end
end
