defmodule AmgrWeb.SEO.JsonLd do
  @moduledoc """
  Generates JSON-LD structured data for articles.

  https://developers.google.com/search/docs/appearance/structured-data/article
  """

  def build(%Amgr.Blog.Post{} = post, url) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Article",
      "headline" => post.title,
      "description" => post.description,
      "datePublished" => Date.to_iso8601(post.date),
      "dateModified" => Date.to_iso8601(post.date),
      "url" => url,
      "author" => %{
        "@type" => "Person",
        "name" => "Allan MacGregor",
        "url" => "https://allanmacgregor.com/about"
      },
      "publisher" => %{
        "@type" => "Person",
        "name" => "Allan MacGregor",
        "url" => "https://allanmacgregor.com"
      },
      "mainEntityOfPage" => %{
        "@type" => "WebPage",
        "@id" => url
      }
    }
    |> maybe_add_image(post)
    |> Jason.encode!()
  end

  def build(%Amgr.Til.Post{} = post, url) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Article",
      "headline" => post.title,
      "description" => post.description,
      "datePublished" => Date.to_iso8601(post.date),
      "dateModified" => Date.to_iso8601(post.date),
      "url" => url,
      "author" => %{
        "@type" => "Person",
        "name" => "Allan MacGregor",
        "url" => "https://allanmacgregor.com/about"
      },
      "publisher" => %{
        "@type" => "Person",
        "name" => "Allan MacGregor",
        "url" => "https://allanmacgregor.com"
      },
      "mainEntityOfPage" => %{
        "@type" => "WebPage",
        "@id" => url
      }
    }
    |> Jason.encode!()
  end

  def build(_, _), do: nil

  defp maybe_add_image(json_ld, post) do
    file = "/images/cards/#{post.id}.png"

    exists? =
      [Application.app_dir(:amgr), "/priv/static", file]
      |> Path.join()
      |> File.exists?()

    if exists? do
      asset_url = Application.get_env(:amgr, AmgrWeb.Endpoint)[:asset_url] || ""
      image_url = asset_url <> "/images/cards/#{post.id}.png"
      Map.put(json_ld, "image", image_url)
    else
      json_ld
    end
  end
end
