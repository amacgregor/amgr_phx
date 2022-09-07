defmodule Mix.Tasks.Images do
  @moduledoc """
  Mix tasks for Generating the Social Media images for blog and til posts
  """

  use Mix.Task

  @shortdoc "Generate Social Media images for blog posts"
  @impl Mix.Task
  def run(_) do
    Enum.each(Amgr.Blog.all_posts(), fn post ->
      Mix.shell().info("Converting #{post.id}")

      System.cmd(File.cwd!() <> "/bin/make-post-image.sh", [
        post.id,
        post.title,
        "./priv/static/images/patterns/pattern-abstract-3.png"
      ])
    end)

    Enum.each(Amgr.Til.all_posts(), fn post ->
      Mix.shell().info("Converting #{post.id}")

      System.cmd(File.cwd!() <> "/bin/make-post-image.sh", [
        post.id,
        "TIL: " <> post.title,
        "./priv/static/images/patterns/pattern-abstract-2.png"
      ])
    end)
  end
end
