defmodule Mix.Tasks.Drafts do
  @moduledoc """
  Interactive TUI for managing draft posts.

  Lists all drafts in priv/drafts/ and allows publishing them to content/posts/
  with automatic date prefixing and frontmatter updates.

  Automatically generates a social media card image after publishing.

  Optionally creates a Typefully draft/post for social media promotion when
  TYPEFULLY_API_KEY and TYPEFULLY_SOCIAL_SET_ID environment variables are set.

  ## Usage

      mix drafts

  """

  use Mix.Task

  alias Amgr.CardGenerator
  alias Amgr.Typefully

  @shortdoc "Manage draft posts - list, preview, and publish"

  @drafts_dir "priv/drafts"
  @posts_dir "content/posts"

  @impl Mix.Task
  def run(_args) do
    loop()
  end

  defp loop do
    drafts = list_drafts()

    if Enum.empty?(drafts) do
      IO.puts("\n  No drafts found in #{@drafts_dir}/\n")
    else
      display_drafts(drafts)
      prompt_action(drafts)
    end
  end

  defp list_drafts do
    Path.wildcard(Path.join(@drafts_dir, "*.md"))
    |> Enum.map(&extract_draft_info/1)
    |> Enum.sort_by(& &1.filename)
  end

  defp extract_draft_info(path) do
    content = File.read!(path)
    {frontmatter, _body} = parse_frontmatter(content)

    %{
      path: path,
      filename: Path.basename(path),
      title: frontmatter[:title] || Path.basename(path, ".md"),
      description: frontmatter[:description],
      tags: frontmatter[:tags] || [],
      category: frontmatter[:category],
      card_theme: frontmatter[:card_theme]
    }
  end

  defp parse_frontmatter(content) do
    case Regex.run(~r/^%\{(.*?)\}\s*---/s, content) do
      [full_match, frontmatter_str] ->
        frontmatter =
          try do
            {map, _} = Code.eval_string("%{#{frontmatter_str}}")
            map
          rescue
            _ -> %{}
          end

        body = String.replace(content, full_match, "") |> String.trim_leading()
        {frontmatter, body}

      _ ->
        {%{}, content}
    end
  end

  defp display_drafts(drafts) do
    IO.puts("\n  ┌─────────────────────────────────────────────────────────────┐")
    IO.puts("  │                      DRAFT POSTS                           │")
    IO.puts("  └─────────────────────────────────────────────────────────────┘\n")

    drafts
    |> Enum.with_index(1)
    |> Enum.each(fn {draft, idx} ->
      IO.puts("  #{format_index(idx)}  #{truncate(draft.title, 55)}")

      if draft.description do
        IO.puts("      #{IO.ANSI.faint()}#{truncate(draft.description, 55)}#{IO.ANSI.reset()}")
      end

      if draft.tags != [] do
        tags = Enum.join(draft.tags, ", ")
        IO.puts("      #{IO.ANSI.cyan()}[#{tags}]#{IO.ANSI.reset()}")
      end

      IO.puts("")
    end)
  end

  defp format_index(idx) when idx < 10, do: " #{idx}."
  defp format_index(idx), do: "#{idx}."

  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max - 3) <> "..."

  defp prompt_action(drafts) do
    IO.puts("  ─────────────────────────────────────────────────────────────")
    IO.puts("  [1-#{length(drafts)}] Publish draft    [q] Quit\n")

    case IO.gets("  > ") |> String.trim() |> String.downcase() do
      "q" ->
        IO.puts("\n  Goodbye!\n")

      "" ->
        loop()

      input ->
        case Integer.parse(input) do
          {num, ""} when num >= 1 and num <= length(drafts) ->
            draft = Enum.at(drafts, num - 1)
            publish_draft(draft)
            loop()

          _ ->
            IO.puts("\n  #{IO.ANSI.red()}Invalid selection#{IO.ANSI.reset()}\n")
            loop()
        end
    end
  end

  defp publish_draft(draft) do
    IO.puts("\n  Publishing: #{draft.title}\n")

    date = prompt_date()
    new_filename = "#{format_date(date)}-#{draft.filename}"
    new_path = Path.join(@posts_dir, new_filename)

    IO.puts("\n  Will create: #{new_path}")
    IO.puts("  Confirm publish? [y/N]: ")

    confirm = IO.gets("  > ") |> String.trim() |> String.downcase()

    if confirm != "y" do
      IO.puts("  #{IO.ANSI.yellow()}Cancelled#{IO.ANSI.reset()}\n")
    else
      do_publish(draft, new_path)
    end
  end

  defp do_publish(draft, new_path) do
    with :ok <- check_target_not_exists(new_path),
         :ok <- check_source_exists(draft.path),
         {:ok, content} <- File.read(draft.path),
         updated_content = update_frontmatter_published(content),
         :ok <- File.write(new_path, updated_content) do
      print_success("✓ Published to #{new_path}")
      remove_draft(draft.path)
      generate_card(draft, new_path)
      prompt_typefully(draft, new_path)
    else
      {:error, :target_exists} ->
        print_error("Error: #{Path.basename(new_path)} already exists!")

      {:error, :source_missing} ->
        print_error("Error: Draft file not found: #{draft.path}")

      {:error, reason} ->
        print_error("Error: #{inspect(reason)}")
    end
  end

  defp generate_card(draft, new_path) do
    # Extract the post ID from the new filename (YYYYMMDD-slug.md -> slug)
    post_id = extract_post_id(new_path)

    # Build a minimal post struct for card generation
    post = %Amgr.Blog.Post{
      id: post_id,
      title: draft.title,
      description: draft.description || "",
      tags: draft.tags,
      date: Date.utc_today(),
      body: "",
      reading_time: 0,
      card_theme: Map.get(draft, :card_theme)
    }

    IO.puts("  Generating social media card...")

    case CardGenerator.generate(post, force: true) do
      {:ok, path} ->
        print_success("✓ Card generated: #{path}")

      {:error, reason} ->
        print_warning("✗ Card generation failed: #{reason}")
        IO.puts("    Run 'mix cards --post #{post_id}' to retry")
    end
  end

  defp extract_post_id(new_path) do
    new_path
    |> Path.basename(".md")
    |> String.split("-", parts: 2)
    |> List.last()
  end

  defp prompt_typefully(draft, new_path) do
    if Typefully.configured?() do
      post_id = extract_post_id(new_path)
      post_url = "https://allanmacgregor.com/posts/#{post_id}"

      IO.puts("\n  Create Typefully post?")
      IO.puts("  [d] Save as draft  [p] Publish now  [s] Skip")

      case IO.gets("  > ") |> String.trim() |> String.downcase() do
        "d" -> create_typefully_post(draft, post_url, publish_now: false)
        "p" -> create_typefully_post(draft, post_url, publish_now: true)
        _ -> print_warning("Skipped Typefully")
      end
    else
      print_warning(
        "Typefully not configured (missing TYPEFULLY_API_KEY or TYPEFULLY_SOCIAL_SET_ID)"
      )

      :skip
    end
  end

  defp create_typefully_post(draft, post_url, opts) do
    IO.puts("  Creating Typefully post...")

    case Typefully.create_post(draft.title, draft.description || "", post_url, opts) do
      {:ok, :created} ->
        action = if opts[:publish_now], do: "published", else: "draft created"
        print_success("Typefully #{action}")

      {:error, reason} ->
        print_warning("Typefully failed: #{inspect(reason)}")
    end
  end

  defp check_target_not_exists(path) do
    if File.exists?(path), do: {:error, :target_exists}, else: :ok
  end

  defp check_source_exists(path) do
    if File.exists?(path), do: :ok, else: {:error, :source_missing}
  end

  defp remove_draft(path) do
    case File.rm(path) do
      :ok -> print_success("✓ Removed draft #{path}")
      {:error, reason} -> print_warning("✗ Failed to remove draft: #{inspect(reason)}")
    end
  end

  defp print_success(msg), do: IO.puts("  #{IO.ANSI.green()}#{msg}#{IO.ANSI.reset()}\n")
  defp print_error(msg), do: IO.puts("  #{IO.ANSI.red()}#{msg}#{IO.ANSI.reset()}\n")
  defp print_warning(msg), do: IO.puts("  #{IO.ANSI.yellow()}#{msg}#{IO.ANSI.reset()}\n")

  defp prompt_date do
    today = Date.utc_today()
    formatted = Calendar.strftime(today, "%Y-%m-%d")

    IO.puts("  Enter publish date [#{formatted}]: ")

    case IO.gets("  > ") |> String.trim() do
      "" ->
        today

      input ->
        case Date.from_iso8601(input) do
          {:ok, date} ->
            date

          {:error, _} ->
            IO.puts("  #{IO.ANSI.yellow()}Invalid date format, using today#{IO.ANSI.reset()}")
            today
        end
    end
  end

  defp format_date(date) do
    Calendar.strftime(date, "%Y%m%d")
  end

  defp update_frontmatter_published(content) do
    # Replace published: false with published: true
    content = Regex.replace(~r/published:\s*false/, content, "published: true")

    # If published isn't in frontmatter at all, add it
    if String.contains?(content, "published:") do
      content
    else
      # Insert before the closing }
      Regex.replace(~r/(\n)\}/, content, "\\1published: true\n}", global: false)
    end
  end
end
