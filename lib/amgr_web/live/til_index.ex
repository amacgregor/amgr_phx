defmodule AmgrWeb.Live.TilIndex do
  use AmgrWeb, :live_view

  def mount(_params, _session, socket) do
    posts = Amgr.Til.published_posts()

    {:ok,
     socket
     |> assign(:posts, posts)
     |> assign(:page_title, "TIL"), temporary_assigns: [posts: []]}
  end
end
