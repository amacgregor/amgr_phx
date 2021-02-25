defmodule AmgrWeb.RobotView do
  use AmgrWeb, :view
  alias AmgrWeb.SEO.Generic
  @generic %Generic{}

  def render("robots.txt", %{env: :prod}), do: ""
  def render("robots.txt", %{env: _}) do
    """
    User-agent: *
    Disallow: /
    """
  end

  def render("rss.xml", %{}) do
    AmgrWeb.Rss.generate(%AmgrWeb.Rss{
      title: @generic.title,
      author: "David Amgrheisel",
      description: @generic.description,
      posts: Amgr.Blog.published_posts()
    })
  end
end
