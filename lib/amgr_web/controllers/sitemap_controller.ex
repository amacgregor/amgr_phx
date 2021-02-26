defmodule AmgrWeb.SitemapController do
  use AmgrWeb, :controller

  plug :put_layout, false

  def index(conn, _params) do
    posts = Amgr.Blog.all_posts()
    tils = Amgr.Til.all_posts()
    conn
    |> put_resp_content_type("text/xml")
    |> render("index.xml", posts: posts, til: tils)
  end
end
