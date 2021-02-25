defmodule AmgrWeb.RobotController do
  use AmgrWeb, :controller

  def robots(conn, _params) do
    conn
    |> put_resp_content_type("text")
    |> render("robots.txt", %{env: Application.get_env(:amgr, :app_env)})
  end

  @sizes [
    [size: "36x36", density: "0.75"],
    [size: "48x48", density: "1.0"],
    [size: "72x72", density: "1.5"],
    [size: "144x144", density: "2.0"],
    [size: "192x192", density: "3.0"]
  ]

  def site_webmanifest(conn, _params) do
    json(conn, %{
      name: "bernheisel.com",
      short_name: "Amgrheisel",
      icons: for [size: size, density: density] <- @sizes do
        %{
          src: Routes.static_path(conn, "/images/android-chrome-#{size}.png"),
          sizes: size,
          density: density,
          type: "image/png"
        }
      end,
      theme_color: "#663399",
      display: "minimal-ui",
      background_color: "#ffffff"
    })
  end

  def browserconfig(conn, _params) do
    conn
    |> put_resp_content_type("application/xml")
    |> render("browserconfig.xml", %{conn: conn})
  end

  def rss(conn, _params) do
    conn
    |> put_resp_content_type("application/xml")
    |> render("rss.xml", %{conn: conn})
  end
end
