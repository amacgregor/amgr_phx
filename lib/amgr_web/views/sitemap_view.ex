defmodule AmgrWeb.SitemapView do
  use AmgrWeb, :view
  alias AmgrWeb.SEO.Generic
  @generic %Generic{}

  def render("sitemap.xml", %{}) do
    AmgrWeb.Rss.generate(%AmgrWeb.Rss{
      title: @generic.title,
      author: "Allan MacGregor",
      description: @generic.description,
      posts: Amgr.Blog.published_posts()
    })
  end

  def format_date(date) do
    date
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_date()
    |> to_string()
  end

  def root_domain() do
    Application.get_env(:amgr, AmgrWeb.Endpoint)[:asset_url] || ""
  end
end
