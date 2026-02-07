defmodule Amgr.Typefully do
  @moduledoc """
  Client for Typefully API to create social media posts.
  """

  @base_url "https://api.typefully.com/v2"

  @doc """
  Creates a social media post via Typefully.

  Options:
  - `:publish_now` - If true, publishes immediately. If false, saves as draft.
  """
  def create_post(title, description, url, opts \\ []) do
    publish_now = Keyword.get(opts, :publish_now, false)

    body = build_request_body(title, description, url, publish_now)

    case make_request(body) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, :created}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: body}} ->
        {:error, "API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if Typefully integration is configured.
  """
  def configured? do
    api_key() != nil and social_set_id() != nil
  end

  defp build_request_body(title, description, url, publish_now) do
    content = build_content(title, description, url)

    base = %{
      "platforms" => %{
        "x" => %{"enabled" => true, "posts" => [%{"text" => content}]},
        "linkedin" => %{"enabled" => true, "posts" => [%{"text" => content}]},
        "threads" => %{"enabled" => true, "posts" => [%{"text" => content}]},
        "bluesky" => %{"enabled" => true, "posts" => [%{"text" => content}]},
        "mastodon" => %{"enabled" => true, "posts" => [%{"text" => content}]}
      },
      "share" => false
    }

    if publish_now do
      Map.put(base, "publish_at", DateTime.to_iso8601(DateTime.utc_now()))
    else
      base
    end
  end

  defp build_content(title, description, url) do
    if description && description != "" do
      """
      #{title}

      #{description}

      Read more: #{url}\
      """
    else
      """
      #{title}

      Read more: #{url}\
      """
    end
  end

  defp make_request(body) do
    # Ensure Req and its dependencies (Finch) are started for mix tasks
    Application.ensure_all_started(:req)

    Req.post(
      "#{@base_url}/social-sets/#{social_set_id()}/drafts",
      json: body,
      headers: [{"authorization", "Bearer #{api_key()}"}]
    )
  end

  defp api_key, do: System.get_env("TYPEFULLY_API_KEY")
  defp social_set_id, do: System.get_env("TYPEFULLY_SOCIAL_SET_ID")
end
