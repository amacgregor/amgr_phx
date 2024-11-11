defmodule AmgrWeb.Live.EveIndex do
  @moduledoc false

  use AmgrWeb, :live_view

  def mount(_params, _session, socket) do
    posts = Amgr.Eve.published_posts()

    {:ok,
     socket
     |> assign(:posts, posts)
     |> assign(:page_title, "Blog"), temporary_assigns: [posts: []]}
  end
end
