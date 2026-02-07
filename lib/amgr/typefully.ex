defmodule Amgr.Typefully do
  @moduledoc """
  Client for Typefully API to create social media posts.
  """

  @base_url "https://api.typefully.com/v2"

  @doc """
  Creates a social media post via Typefully.

  Options:
  - `:publish_now` - If true, publishes immediately. If false, saves as draft.
  - `:media_ids` - List of media IDs to attach to the post.
  """
  def create_post(title, description, url, opts \\ []) do
    publish_now = Keyword.get(opts, :publish_now, false)
    media_ids = Keyword.get(opts, :media_ids, [])

    body = build_request_body(title, description, url, publish_now, media_ids)

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
  Uploads a media file to Typefully and returns the media_id.

  This is a 3-step process:
  1. Request an upload URL
  2. Upload the file to that URL
  3. Poll until the media is ready

  Returns `{:ok, media_id}` or `{:error, reason}`.
  """
  def upload_media(file_path) do
    Application.ensure_all_started(:req)

    filename = Path.basename(file_path)

    with {:ok, %{media_id: media_id, upload_url: upload_url}} <- request_upload_url(filename),
         :ok <- upload_file(upload_url, file_path),
         :ok <- wait_for_media_ready(media_id) do
      {:ok, media_id}
    end
  end

  defp request_upload_url(filename) do
    url = "#{@base_url}/social-sets/#{social_set_id()}/media/upload"

    case Req.post(url,
           json: %{"file_name" => filename},
           headers: [{"authorization", "Bearer #{api_key()}"}]
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, %{media_id: body["media_id"], upload_url: body["upload_url"]}}

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to get upload URL: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp upload_file(upload_url, file_path) do
    content = File.read!(file_path)
    content_type = content_type_for(file_path)

    case Req.put(upload_url,
           body: content,
           headers: [{"content-type", content_type}]
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to upload file: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp wait_for_media_ready(media_id, attempts \\ 0) do
    max_attempts = 30

    if attempts >= max_attempts do
      {:error, :timeout}
    else
      case check_media_status(media_id) do
        {:ok, "ready"} ->
          :ok

        {:ok, "processing"} ->
          Process.sleep(1000)
          wait_for_media_ready(media_id, attempts + 1)

        {:ok, "failed"} ->
          {:error, :media_processing_failed}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp check_media_status(media_id) do
    url = "#{@base_url}/social-sets/#{social_set_id()}/media/#{media_id}"

    case Req.get(url, headers: [{"authorization", "Bearer #{api_key()}"}]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body["status"]}

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to check media status: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp content_type_for(path) do
    case Path.extname(path) |> String.downcase() do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      _ -> "application/octet-stream"
    end
  end

  @doc """
  Checks if Typefully integration is configured.
  """
  def configured? do
    api_key() != nil and social_set_id() != nil
  end

  defp build_request_body(title, description, url, publish_now, media_ids) do
    content = build_content(title, description, url)
    post = build_post(content, media_ids)

    base = %{
      "platforms" => %{
        "x" => %{"enabled" => true, "posts" => [post]},
        "linkedin" => %{"enabled" => true, "posts" => [post]},
        "threads" => %{"enabled" => true, "posts" => [post]},
        "bluesky" => %{"enabled" => true, "posts" => [post]},
        "mastodon" => %{"enabled" => true, "posts" => [post]}
      },
      "share" => false
    }

    if publish_now do
      Map.put(base, "publish_at", DateTime.to_iso8601(DateTime.utc_now()))
    else
      base
    end
  end

  defp build_post(content, []), do: %{"text" => content}
  defp build_post(content, media_ids), do: %{"text" => content, "media_ids" => media_ids}

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
