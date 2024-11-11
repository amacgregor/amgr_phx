defmodule Mix.Tasks.Posse do
  @moduledoc """
  Mix tasks for Generating content snippets for social media platforms
  """

  use Mix.Task

  @shortdoc "Generate social media content for blog posts"
  @impl Mix.Task
  def run(_) do
    Enum.each(Amgr.Blog.all_posts(), &generate_social_media_posts/1)
  end

  defp generate_social_media_posts(post) do
    generate_twitter_post(post)
    generate_facebook_post(post)
    generate_linkedin_post(post)
  end

  defp generate_twitter_post(post) do
    # Twitter content (limited to 500 characters)
    content = format_content_for_twitter(post)
    write_to_file("twitter_#{post.id}.txt", content)
  end

  defp generate_facebook_post(post) do
    # Facebook content
    content = format_content_for_facebook(post)
    write_to_file("facebook_#{post.id}.txt", content)
  end

  defp generate_linkedin_post(post) do
    # LinkedIn content
    content = format_content_for_linkedin(post)
    write_to_file("linkedin_#{post.id}.txt", content)
  end

  defp format_content_for_twitter(post) do
    body_text = strip_html(post.body)
    base_content = "#{post.title}\n\n#{extract_content_snippet(body_text)}"
    append_link_and_tags(base_content, post.original_url, 500)
  end

  defp format_content_for_facebook(post) do
    body_text = strip_html(post.body)
    base_content = "#{post.title}\n\n#{extract_content_snippet(body_text)}"
    append_link_and_tags(base_content, post.original_url)
  end

  defp format_content_for_linkedin(post) do
    body_text = strip_html(post.body)
    base_content = "#{post.title}\n\n#{extract_content_snippet(body_text)}"
    append_link_and_tags(base_content, post.original_url)
  end

  defp append_link_and_tags(content, link, max_length \\ 3000) do
    # Replace with actual SEO tags
    seo_tags = "#YourSEOtags"
    full_content = "#{content}\nRead more: #{link} #{seo_tags}"
    String.slice(full_content, 0, max_length)
  end

  defp strip_html(html_content) do
    Regex.replace(~r/<[^>]*(.*?)>/, html_content, "")
  end

  defp extract_content_snippet(content, length \\ 3000) do
    String.slice(content, 0, length)
  end

  defp write_to_file(filename, content) do
    File.write!(filename, content)
    IO.puts("Generated content for #{filename}")
  end
end
