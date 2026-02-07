defmodule Amgr.CardGenerator do
  @moduledoc """
  Generates social media card images for blog posts using ImageMagick via Mogrify.

  Cards are 963x481px PNG images with:
  - A pattern background (selectable via theme)
  - Post title overlaid in white
  - Author handle in the corner
  """

  @cards_dir "priv/static/images/cards"
  @patterns_dir "priv/static/images/patterns"
  @fonts_dir "priv/static/fonts"

  @themes %{
    "abstract-1" => "pattern-abstract-1.png",
    "abstract-2" => "pattern-abstract-2.png",
    "abstract-3" => "pattern-abstract-3.png",
    "abstract-4" => "pattern-abstract-4.png",
    "cyberpunk-1" => "pattern-cyberpunk-1.png",
    "cyberpunk-2" => "pattern-cyberpunk-2.png"
  }

  @default_blog_theme "abstract-3"
  @default_til_theme "abstract-2"

  @doc """
  Returns list of available theme names.
  """
  def available_themes, do: Map.keys(@themes)

  @doc """
  Generates a card image for the given post.

  Options:
  - `:force` - Regenerate even if card exists (default: false)
  - `:theme` - Override the theme (default: uses post.card_theme or type default)

  Returns:
  - `{:ok, path}` on success
  - `{:skip, reason}` if skipped
  - `{:error, reason}` on failure
  """
  def generate(post, opts \\ []) do
    force = Keyword.get(opts, :force, false)
    output_path = card_path(post.id)

    if not force and File.exists?(output_path) do
      {:skip, :exists}
    else
      do_generate(post, output_path, opts)
    end
  end

  @doc """
  Returns the path where a card would be stored for the given post ID.
  """
  def card_path(post_id) do
    Path.join(@cards_dir, "#{post_id}.png")
  end

  @doc """
  Checks if a card exists for the given post ID.
  """
  def card_exists?(post_id) do
    File.exists?(card_path(post_id))
  end

  defp do_generate(post, output_path, opts) do
    ensure_cards_dir!()

    theme = resolve_theme(post, opts)
    pattern_path = pattern_path(theme)

    if File.exists?(pattern_path) do
      title = format_title(post)

      case generate_card(pattern_path, title, output_path) do
        :ok -> {:ok, output_path}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Pattern not found: #{pattern_path}"}
    end
  end

  defp resolve_theme(post, opts) do
    cond do
      theme = Keyword.get(opts, :theme) ->
        theme

      card_theme = Map.get(post, :card_theme) ->
        card_theme

      post.__struct__ == Amgr.Til.Post ->
        @default_til_theme

      true ->
        @default_blog_theme
    end
  end

  defp pattern_path(theme) do
    pattern_file = Map.get(@themes, theme, "pattern-abstract-3.png")
    Path.join(@patterns_dir, pattern_file)
  end

  defp format_title(post) do
    case post.__struct__ do
      Amgr.Til.Post -> "TIL: #{post.title}"
      _ -> post.title
    end
  end

  defp ensure_cards_dir! do
    File.mkdir_p!(@cards_dir)
  end

  defp generate_card(pattern_path, title, output_path) do
    title_font = Path.join(@fonts_dir, "Inter-SemiBold.otf")
    author_font = Path.join(@fonts_dir, "FiraCode-SemiBold.ttf")

    # Build ImageMagick command manually for complex composite operations
    # Mogrify doesn't support all the composite operations we need
    args = [
      pattern_path,
      # Author label
      "(",
      "-background",
      "none",
      "-fill",
      "white",
      "-size",
      "320x",
      "-font",
      author_font,
      "label:allanmacgregor",
      ")",
      "-gravity",
      "southeast",
      "-geometry",
      "+40+20",
      "-compose",
      "over",
      "-composite",
      # Title
      "(",
      "-background",
      "none",
      "-fill",
      "white",
      "-size",
      "900x381",
      "-font",
      title_font,
      "-size",
      "900x381",
      "caption:#{title}",
      ")",
      "-gravity",
      "northeast",
      "-geometry",
      "+40+0",
      "-compose",
      "over",
      "-composite",
      output_path
    ]

    case System.cmd("convert", args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> {:error, error}
    end
  end
end
