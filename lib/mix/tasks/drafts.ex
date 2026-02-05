defmodule Mix.Tasks.Drafts do
  @moduledoc """
  Interactive TUI for managing draft posts.

  Lists all drafts in priv/drafts/ and allows publishing them to content/posts/
  with automatic date prefixing and frontmatter updates.

  ## Usage

      mix drafts

  """

  use Mix.Task

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
      category: frontmatter[:category]
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
    cond do
      File.exists?(new_path) ->
        IO.puts("  #{IO.ANSI.red()}Error: #{Path.basename(new_path)} already exists!#{IO.ANSI.reset()}\n")

      not File.exists?(draft.path) ->
        IO.puts("  #{IO.ANSI.red()}Error: Draft file not found: #{draft.path}#{IO.ANSI.reset()}\n")

      true ->
        case File.read(draft.path) do
          {:ok, content} ->
            updated_content = update_frontmatter_published(content)

            case File.write(new_path, updated_content) do
              :ok ->
                case File.rm(draft.path) do
                  :ok ->
                    IO.puts("  #{IO.ANSI.green()}✓ Published to #{new_path}#{IO.ANSI.reset()}")
                    IO.puts("  #{IO.ANSI.green()}✓ Removed draft #{draft.path}#{IO.ANSI.reset()}\n")

                  {:error, reason} ->
                    IO.puts("  #{IO.ANSI.yellow()}✓ Published to #{new_path}#{IO.ANSI.reset()}")
                    IO.puts("  #{IO.ANSI.red()}✗ Failed to remove draft: #{inspect(reason)}#{IO.ANSI.reset()}\n")
                end

              {:error, reason} ->
                IO.puts("  #{IO.ANSI.red()}Error writing file: #{inspect(reason)}#{IO.ANSI.reset()}\n")
            end

          {:error, reason} ->
            IO.puts("  #{IO.ANSI.red()}Error reading draft: #{inspect(reason)}#{IO.ANSI.reset()}\n")
        end
    end
  end

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
