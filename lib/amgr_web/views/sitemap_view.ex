defmodule AmgrWeb.SitemapView do
  use AmgrWeb, :view

  def root_domain() do
    Application.get_env(:amgr, AmgrWeb.Endpoint)[:asset_url] || ""
  end
end
