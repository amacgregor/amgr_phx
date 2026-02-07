defmodule AmgrWeb.SEO do
  @moduledoc "You know, juice."

  use AmgrWeb, :view
  alias AmgrWeb.SEO.{Generic, Breadcrumbs, OpenGraph, JsonLd}

  @default_assigns %{site: %Generic{}, breadcrumbs: nil, og: nil, json_ld: nil, noindex: false}

  def meta(conn, AmgrWeb.Live.BlogShow, %{post: post}) do
    url = Phoenix.Controller.current_url(conn)

    render(
      "meta.html",
      @default_assigns
      |> put_opengraph_tags(conn, post)
      |> put_breadcrumbs(conn, post)
      |> put_json_ld(post, url)
    )
  end

  def meta(conn, AmgrWeb.Live.TilShow, %{post: post}) do
    url = Phoenix.Controller.current_url(conn)

    render(
      "meta.html",
      @default_assigns
      |> put_opengraph_tags(conn, post)
      |> put_breadcrumbs(conn, post)
      |> put_json_ld(post, url)
    )
  end

  def meta(_, AmgrWeb.Live.EveIndex, _) do
    render(
      "meta.html",
      @default_assigns
      |> Map.put(:noindex, true)
    )
  end

  def meta(conn, AmgrWeb.Live.EveShow, %{post: post}) do
    render(
      "meta.html",
      @default_assigns
      |> put_opengraph_tags(conn, post)
      |> put_breadcrumbs(conn, post)
      |> Map.put(:noindex, true)
    )
  end

  def meta(_, AmgrWeb.Live.BlogIndex, _) do
    render(
      "meta.html",
      @default_assigns
      |> put_site_description("Technical articles on Elixir, Phoenix, and software architecture.")
    )
  end

  def meta(_, AmgrWeb.Live.Publications, _) do
    render(
      "meta.html",
      @default_assigns
      |> put_site_description("Published articles and podcast appearances by Allan MacGregor.")
    )
  end

  def meta(_, AmgrWeb.Live.Page, %{"page" => "about"}) do
    render(
      "meta.html",
      @default_assigns
      |> put_site_description(
        "About Allan MacGregor - CTO and software architect focused on Elixir and fintech."
      )
    )
  end

  def meta(_, _, _), do: render("meta.html", @default_assigns)

  defp put_opengraph_tags(assigns, conn, event),
    do: Map.put(assigns, :og, OpenGraph.build(conn, event))

  defp put_breadcrumbs(assigns, conn, event),
    do: Map.put(assigns, :breadcrumbs, Breadcrumbs.build(conn, event))

  defp put_json_ld(assigns, post, url),
    do: Map.put(assigns, :json_ld, JsonLd.build(post, url))

  defp put_site_description(assigns, description) do
    site = %Generic{assigns.site | description: description}
    Map.put(assigns, :site, site)
  end
end
