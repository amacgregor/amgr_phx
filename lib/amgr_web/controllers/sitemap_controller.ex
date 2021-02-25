defmodule AmgrWeb.SitemapController do
  use AmgrWeb, :controller

  plug :put_layout, false

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/xml")
    |> render("index.xml")
  end
end
