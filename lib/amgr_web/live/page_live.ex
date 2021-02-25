defmodule AmgrWeb.Live.Page do
  use AmgrWeb, :live_view

  @impl true
  def mount(_params, %{"page" => page}, socket) do
    {:ok, socket |> assign(page: page) |> assign(:page_title, String.capitalize(page))}
  end
  def mount(_params, _, socket), do: {:ok, redirect(socket, to: Routes.post_path(socket, :index))}

  @impl true
  def render(assigns) do
    AmgrWeb.PageView.render(assigns.page <> ".html", assigns)
  end
end
