defmodule AmgrWeb.SEO do
  @moduledoc "You know, juice."

  use AmgrWeb, :view
  alias AmgrWeb.SEO.{Generic, Breadcrumbs, OpenGraph}

  @default_assigns %{site: %Generic{}, breadcrumbs: nil, og: nil}

  def meta(conn, AmgrWeb.Live.BlogShow, %{post: post}) do
    render(
      "meta.html",
      @default_assigns
      |> put_opengraph_tags(conn, post)
      |> put_breadcrumbs(conn, post)
    )
  end
  def meta(_, _, _), do: render("meta.html", @default_assigns)

  def put_opengraph_tags(assigns, conn, event),
    do: Map.put(assigns, :og, OpenGraph.build(conn, event))

  def put_breadcrumbs(assigns, conn, event),
    do: Map.put(assigns, :breadcrumbs, Breadcrumbs.build(conn, event))
end
