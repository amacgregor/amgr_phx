defmodule AmgrWeb.LayoutView do
  use AmgrWeb, :view

  def seo_tags(%{live_seo: true} = assigns) do
    {module, _, _} = assigns.conn.private.phoenix_live_view
    AmgrWeb.SEO.meta(assigns.conn, module, assigns)
  end

  def seo_tags(_assigns), do: nil
end
