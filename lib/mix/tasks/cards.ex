defmodule Mix.Tasks.Cards do
  @moduledoc """
  Generate social media card images for blog posts.

  ## Usage

      mix cards              # Generate missing cards only
      mix cards --all        # Regenerate all cards
      mix cards --post ID    # Generate card for specific post
      mix cards --list       # List posts and card status
      mix cards --themes     # Show available themes

  ## Options

      --all           Regenerate all cards (overwrites existing)
      --post ID       Generate card for a specific post by ID
      --theme THEME   Override theme for this generation
      --list          List all posts with their card status
      --themes        Show available themes

  ## Examples

      mix cards
      mix cards --all
      mix cards --post circuit-breaker-pattern-in-elixir
      mix cards --post my-post --theme cyberpunk-1

  """

  use Mix.Task

  alias Amgr.CardGenerator

  @shortdoc "Generate social media card images for blog posts"

  @switches [
    all: :boolean,
    post: :string,
    theme: :string,
    list: :boolean,
    themes: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    cond do
      opts[:themes] ->
        show_themes()

      opts[:list] ->
        list_posts()

      opts[:post] ->
        generate_single(opts[:post], opts)

      opts[:all] ->
        generate_all(force: true)

      true ->
        generate_all(force: false)
    end
  end

  defp show_themes do
    IO.puts("\n  Available themes:\n")

    CardGenerator.available_themes()
    |> Enum.sort()
    |> Enum.each(fn theme ->
      IO.puts("    - #{theme}")
    end)

    IO.puts("")
  end

  defp list_posts do
    IO.puts("\n  Blog Posts:\n")
    list_posts_for(Amgr.Blog.all_posts(), "blog")

    IO.puts("\n  TIL Posts:\n")
    list_posts_for(Amgr.Til.all_posts(), "til")
  end

  defp list_posts_for(posts, _type) do
    posts
    |> Enum.each(fn post ->
      status =
        if CardGenerator.card_exists?(post.id) do
          IO.ANSI.green() <> "[ok]" <> IO.ANSI.reset()
        else
          IO.ANSI.yellow() <> "[missing]" <> IO.ANSI.reset()
        end

      IO.puts("    #{status} #{post.id}")
    end)

    total = length(posts)
    with_cards = Enum.count(posts, &CardGenerator.card_exists?(&1.id))
    missing = total - with_cards

    IO.puts("")
    IO.puts("    Total: #{total}, With cards: #{with_cards}, Missing: #{missing}")
  end

  defp generate_single(post_id, opts) do
    post = find_post(post_id)

    case post do
      nil ->
        Mix.shell().error("Post not found: #{post_id}")

      post ->
        theme = opts[:theme]
        generate_opts = if theme, do: [force: true, theme: theme], else: [force: true]

        case CardGenerator.generate(post, generate_opts) do
          {:ok, path} ->
            Mix.shell().info("#{IO.ANSI.green()}Generated#{IO.ANSI.reset()} #{path}")

          {:error, reason} ->
            Mix.shell().error("Failed: #{reason}")
        end
    end
  end

  defp generate_all(opts) do
    force = Keyword.get(opts, :force, false)
    mode = if force, do: "Regenerating all", else: "Generating missing"

    IO.puts("\n  #{mode} cards...\n")

    blog_stats = generate_for_posts(Amgr.Blog.all_posts(), "Blog", force)
    til_stats = generate_for_posts(Amgr.Til.all_posts(), "TIL", force)

    total_generated = blog_stats.generated + til_stats.generated
    total_skipped = blog_stats.skipped + til_stats.skipped
    total_failed = blog_stats.failed + til_stats.failed

    IO.puts("")
    IO.puts("  Summary:")
    IO.puts("    Generated: #{total_generated}")
    IO.puts("    Skipped:   #{total_skipped}")

    if total_failed > 0 do
      IO.puts("    #{IO.ANSI.red()}Failed:    #{total_failed}#{IO.ANSI.reset()}")
    end

    IO.puts("")
  end

  defp generate_for_posts(posts, label, force) do
    IO.puts("  #{label} posts:")

    stats =
      posts
      |> Enum.reduce(%{generated: 0, skipped: 0, failed: 0}, fn post, acc ->
        case CardGenerator.generate(post, force: force) do
          {:ok, _path} ->
            IO.puts("    #{IO.ANSI.green()}+#{IO.ANSI.reset()} #{post.id}")
            %{acc | generated: acc.generated + 1}

          {:skip, :exists} ->
            %{acc | skipped: acc.skipped + 1}

          {:error, reason} ->
            IO.puts("    #{IO.ANSI.red()}!#{IO.ANSI.reset()} #{post.id}: #{reason}")
            %{acc | failed: acc.failed + 1}
        end
      end)

    if stats.generated == 0 and stats.failed == 0 do
      IO.puts("    (all cards exist)")
    end

    stats
  end

  defp find_post(id) do
    Amgr.Blog.all_posts()
    |> Enum.find(&(&1.id == id))
    |> case do
      nil -> Amgr.Til.all_posts() |> Enum.find(&(&1.id == id))
      post -> post
    end
  end
end
