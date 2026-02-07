%{
title: "Elixir and AI: Building LLM-Powered Features",
category: "Programming",
tags: ["elixir", "ai", "llm", "openai", "machine-learning"],
description: "Using Instructor for structured LLM output and building AI features in Elixir",
published: false
}
---

# Elixir and AI: Building LLM-Powered Features

The conventional wisdom says Python owns the AI stack. Every tutorial, every example, every getting-started guide assumes you are writing Python. This makes sense for model training and research. It makes far less sense for production systems that need to serve AI features to real users.

Here is the uncomfortable truth: most AI-powered features are not training models. They are calling APIs, processing responses, handling failures gracefully, and serving results to users who expect sub-second latency. This is exactly the domain where Elixir excels.

## Why Elixir for AI Applications

The BEAM virtual machine was designed for telecom switches — systems that process millions of concurrent operations, never go down, and recover gracefully from failures. These properties translate directly to AI workloads in production.

**Concurrency without complexity.** When you call an LLM API, you wait. OpenAI's GPT-4 might take 2-10 seconds to respond. In a thread-per-request model, this is catastrophic — your server threads are blocked, your throughput craters, and you start dropping requests. Elixir's lightweight processes handle this elegantly. Spawn 10,000 concurrent LLM requests and your system does not even notice. Each request runs in its own process, waiting on I/O without consuming meaningful resources.

**Fault tolerance for unreliable dependencies.** LLM APIs fail. They timeout. They return malformed responses. They rate-limit you without warning. In most languages, you handle this with try-catch blocks and retry logic scattered throughout your codebase. In Elixir, you design supervision trees that encode your recovery strategy. A failed API call crashes its process, the supervisor restarts it, and the rest of your system continues unaffected.

**Natural fit for streaming.** Modern LLM APIs stream tokens as they generate. This is not a nice-to-have — it is the difference between a UI that feels responsive and one that feels broken. Phoenix LiveView and Elixir's process model make streaming trivial to implement and reason about.

## LLM API Clients in Elixir

The Elixir ecosystem has matured considerably for LLM integration. Two libraries dominate: `openai_ex` for OpenAI's APIs and `anthropix` for Anthropic's Claude models.

### OpenAI Integration

```elixir
# mix.exs
defp deps do
  [
    {:openai_ex, "~> 0.8"},
    {:instructor, "~> 0.1"}
  ]
end
```

```elixir
defmodule MyApp.LLM.OpenAI do
  @moduledoc """
  OpenAI API client wrapper with sensible defaults.
  """

  def client do
    OpenaiEx.new(System.get_env("OPENAI_API_KEY"))
    |> OpenaiEx.with_receive_timeout(60_000)
  end

  def chat_completion(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "gpt-4-turbo")
    temperature = Keyword.get(opts, :temperature, 0.7)

    request = %{
      model: model,
      messages: messages,
      temperature: temperature
    }

    case OpenaiEx.Chat.Completions.create(client(), request) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        {:ok, content}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Anthropic Integration

```elixir
defmodule MyApp.LLM.Anthropic do
  @moduledoc """
  Anthropic Claude API client.
  """

  @base_url "https://api.anthropic.com/v1"

  def chat(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "claude-3-5-sonnet-20241022")
    max_tokens = Keyword.get(opts, :max_tokens, 4096)

    body = %{
      model: model,
      max_tokens: max_tokens,
      messages: format_messages(messages)
    }

    headers = [
      {"x-api-key", System.get_env("ANTHROPIC_API_KEY")},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    case Req.post("#{@base_url}/messages", json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_messages(messages) do
    Enum.map(messages, fn
      %{role: role, content: content} -> %{"role" => to_string(role), "content" => content}
      map when is_map(map) -> map
    end)
  end
end
```

## Instructor: Structured LLM Output

Raw LLM output is a string. You want structured data. The gap between these two is where bugs breed.

The Instructor library solves this elegantly by leveraging Ecto schemas to define expected output shapes. The library handles prompt engineering, JSON schema generation, and response validation automatically.

```elixir
defmodule MyApp.AI.Schemas.SentimentAnalysis do
  use Ecto.Schema
  use Instructor.Validator

  @llm_doc """
  Analyze the sentiment of the provided text.
  """

  @primary_key false
  embedded_schema do
    field :sentiment, Ecto.Enum, values: [:positive, :negative, :neutral]
    field :confidence, :float
    field :reasoning, :string
  end

  @impl true
  def validate_changeset(changeset) do
    changeset
    |> Ecto.Changeset.validate_number(:confidence,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> Ecto.Changeset.validate_required([:sentiment, :confidence, :reasoning])
  end
end
```

```elixir
defmodule MyApp.AI.Analyzer do
  def analyze_sentiment(text) do
    Instructor.chat_completion(
      model: "gpt-4-turbo",
      response_model: MyApp.AI.Schemas.SentimentAnalysis,
      messages: [
        %{role: "user", content: "Analyze the sentiment of this text: #{text}"}
      ]
    )
  end
end
```

The response is not a string you need to parse. It is an Ecto struct with validated fields.

```elixir
{:ok, %MyApp.AI.Schemas.SentimentAnalysis{
  sentiment: :positive,
  confidence: 0.92,
  reasoning: "The text uses enthusiastic language..."
}}
```

### Complex Structured Extraction

Instructor shines when extracting complex, nested data.

```elixir
defmodule MyApp.AI.Schemas.ExtractedContact do
  use Ecto.Schema
  use Instructor.Validator

  @primary_key false
  embedded_schema do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :company, :string

    embeds_many :addresses, Address, primary_key: false do
      field :street, :string
      field :city, :string
      field :state, :string
      field :zip, :string
      field :type, Ecto.Enum, values: [:home, :work, :other]
    end
  end

  @impl true
  def validate_changeset(changeset) do
    changeset
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_format(:email, ~r/@/)
  end
end
```

```elixir
def extract_contact_info(raw_text) do
  Instructor.chat_completion(
    model: "gpt-4-turbo",
    response_model: MyApp.AI.Schemas.ExtractedContact,
    messages: [
      %{
        role: "system",
        content: "Extract contact information from the provided text. Be thorough."
      },
      %{role: "user", content: raw_text}
    ]
  )
end
```

This is the difference between hoping the LLM returns valid JSON and knowing it does. The schema is the contract. Instructor enforces it.

## Streaming LLM Responses in LiveView

Users do not wait well. A 5-second spinner while GPT thinks is a UX failure. Streaming tokens as they generate transforms the experience — users see progress, can start reading immediately, and perceive the system as faster even when total latency is identical.

Phoenix LiveView makes this implementation straightforward.

```elixir
defmodule MyAppWeb.ChatLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, messages: [], streaming: false, current_response: "")}
  end

  def handle_event("send_message", %{"message" => content}, socket) do
    user_message = %{role: :user, content: content}
    messages = socket.assigns.messages ++ [user_message]

    # Start streaming in a separate process
    pid = self()
    Task.start(fn -> stream_response(messages, pid) end)

    {:noreply,
     socket
     |> assign(messages: messages, streaming: true, current_response: "")}
  end

  def handle_info({:stream_chunk, chunk}, socket) do
    current = socket.assigns.current_response <> chunk
    {:noreply, assign(socket, current_response: current)}
  end

  def handle_info(:stream_complete, socket) do
    assistant_message = %{role: :assistant, content: socket.assigns.current_response}

    {:noreply,
     socket
     |> assign(
       messages: socket.assigns.messages ++ [assistant_message],
       streaming: false,
       current_response: ""
     )}
  end

  defp stream_response(messages, pid) do
    OpenaiEx.Chat.Completions.create(
      MyApp.LLM.OpenAI.client(),
      %{
        model: "gpt-4-turbo",
        messages: format_messages(messages),
        stream: true
      },
      stream: fn
        %{"choices" => [%{"delta" => %{"content" => content}}]} when is_binary(content) ->
          send(pid, {:stream_chunk, content})

        %{"choices" => [%{"finish_reason" => "stop"}]} ->
          send(pid, :stream_complete)

        _other ->
          :ok
      end
    )
  end

  defp format_messages(messages) do
    Enum.map(messages, fn %{role: role, content: content} ->
      %{"role" => to_string(role), "content" => content}
    end)
  end
end
```

```heex
<div class="chat-container">
  <%= for message <- @messages do %>
    <div class={"message #{message.role}"}>
      <%= message.content %>
    </div>
  <% end %>

  <%= if @streaming do %>
    <div class="message assistant streaming">
      <%= @current_response %><span class="cursor">|</span>
    </div>
  <% end %>
</div>

<form phx-submit="send_message">
  <input type="text" name="message" disabled={@streaming} />
  <button type="submit" disabled={@streaming}>Send</button>
</form>
```

The key insight: streaming is just message passing. The LLM client sends chunks to the LiveView process, which updates the socket assigns. Phoenix handles the WebSocket push to the browser. No polling, no complexity.

## Building an AI Agent Pattern

An AI agent is a loop: observe state, decide action, execute action, observe new state. Elixir's GenServer is purpose-built for this pattern.

```elixir
defmodule MyApp.Agent do
  use GenServer
  require Logger

  defmodule State do
    defstruct [:goal, :context, :history, :max_iterations, :current_iteration]
  end

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def run(pid, goal) do
    GenServer.call(pid, {:run, goal}, :infinity)
  end

  # Server callbacks
  @impl true
  def init(opts) do
    {:ok,
     %State{
       context: Keyword.get(opts, :context, %{}),
       history: [],
       max_iterations: Keyword.get(opts, :max_iterations, 10),
       current_iteration: 0
     }}
  end

  @impl true
  def handle_call({:run, goal}, _from, state) do
    state = %{state | goal: goal, current_iteration: 0, history: []}
    result = run_loop(state)
    {:reply, result, state}
  end

  defp run_loop(%{current_iteration: i, max_iterations: max} = state) when i >= max do
    {:error, :max_iterations_exceeded}
  end

  defp run_loop(state) do
    case decide_action(state) do
      {:complete, result} ->
        {:ok, result}

      {:action, action, params} ->
        case execute_action(action, params, state) do
          {:ok, observation} ->
            new_history = state.history ++ [{action, params, observation}]
            new_state = %{state | history: new_history, current_iteration: state.current_iteration + 1}
            run_loop(new_state)

          {:error, reason} ->
            {:error, {:action_failed, action, reason}}
        end
    end
  end

  defp decide_action(state) do
    prompt = build_decision_prompt(state)

    case MyApp.AI.decide(prompt) do
      {:ok, %{action: "complete", result: result}} ->
        {:complete, result}

      {:ok, %{action: action, params: params}} ->
        {:action, String.to_existing_atom(action), params}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_action(:search, %{query: query}, _state) do
    MyApp.Tools.search(query)
  end

  defp execute_action(:calculate, %{expression: expr}, _state) do
    MyApp.Tools.calculate(expr)
  end

  defp execute_action(:fetch_url, %{url: url}, _state) do
    MyApp.Tools.fetch_url(url)
  end

  defp build_decision_prompt(state) do
    history_text =
      state.history
      |> Enum.map(fn {action, params, observation} ->
        "Action: #{action}(#{inspect(params)})\nObservation: #{observation}"
      end)
      |> Enum.join("\n\n")

    """
    Goal: #{state.goal}

    Available actions: search, calculate, fetch_url, complete

    History:
    #{history_text}

    What action should be taken next? If the goal is achieved, use action "complete" with the result.
    """
  end
end
```

The GenServer maintains agent state across iterations. The supervision tree handles crashes — if an agent dies mid-execution, it restarts cleanly. The loop terminates either when the LLM decides the goal is complete or when the iteration limit is reached.

## Caching and Rate Limiting

LLM calls are expensive in both latency and cost. Caching identical requests is obvious. Rate limiting protects you from runaway costs and API bans.

### Response Caching with Cachex

```elixir
defmodule MyApp.LLM.CachedClient do
  @cache_name :llm_cache
  @default_ttl :timer.hours(24)

  def chat_completion(messages, opts \\ []) do
    cache_key = build_cache_key(messages, opts)

    case Cachex.get(@cache_name, cache_key) do
      {:ok, nil} ->
        result = MyApp.LLM.OpenAI.chat_completion(messages, opts)

        case result do
          {:ok, response} ->
            ttl = Keyword.get(opts, :cache_ttl, @default_ttl)
            Cachex.put(@cache_name, cache_key, response, ttl: ttl)

          _error ->
            :ok
        end

        result

      {:ok, cached} ->
        {:ok, cached}
    end
  end

  defp build_cache_key(messages, opts) do
    data = {messages, Keyword.take(opts, [:model, :temperature])}
    :crypto.hash(:sha256, :erlang.term_to_binary(data))
  end
end
```

### Rate Limiting with Hammer

```elixir
defmodule MyApp.LLM.RateLimitedClient do
  @bucket "openai_api"
  @scale_ms :timer.minutes(1)
  @limit 60

  def chat_completion(messages, opts \\ []) do
    case Hammer.check_rate(@bucket, @scale_ms, @limit) do
      {:allow, _count} ->
        MyApp.LLM.CachedClient.chat_completion(messages, opts)

      {:deny, retry_after} ->
        {:error, {:rate_limited, retry_after}}
    end
  end

  def chat_completion_with_retry(messages, opts \\ [], retries \\ 3) do
    case chat_completion(messages, opts) do
      {:error, {:rate_limited, retry_after}} when retries > 0 ->
        Process.sleep(retry_after)
        chat_completion_with_retry(messages, opts, retries - 1)

      result ->
        result
    end
  end
end
```

Combine these into a single client module that your application uses everywhere. The caching and rate limiting become invisible to calling code.

## Testing AI Features

Testing LLM integrations requires strategy. You cannot rely on the actual API — it is slow, expensive, and non-deterministic. But you also cannot ignore the integration entirely.

### Mocking with Mox

```elixir
# test/support/mocks.ex
Mox.defmock(MyApp.LLM.MockClient, for: MyApp.LLM.ClientBehaviour)

# lib/my_app/llm/client_behaviour.ex
defmodule MyApp.LLM.ClientBehaviour do
  @callback chat_completion(list(), keyword()) :: {:ok, String.t()} | {:error, term()}
end

# In your actual client
defmodule MyApp.LLM.OpenAI do
  @behaviour MyApp.LLM.ClientBehaviour
  # ... implementation
end
```

```elixir
# test/my_app/ai/analyzer_test.exs
defmodule MyApp.AI.AnalyzerTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  describe "analyze_sentiment/1" do
    test "returns structured sentiment for positive text" do
      expect(MyApp.LLM.MockClient, :chat_completion, fn _messages, _opts ->
        {:ok, ~s({"sentiment": "positive", "confidence": 0.95, "reasoning": "Test"})}
      end)

      assert {:ok, %{sentiment: :positive}} =
               MyApp.AI.Analyzer.analyze_sentiment("I love this product!")
    end

    test "handles API errors gracefully" do
      expect(MyApp.LLM.MockClient, :chat_completion, fn _messages, _opts ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = MyApp.AI.Analyzer.analyze_sentiment("test")
    end
  end
end
```

### Integration Tests with Recorded Responses

For critical paths, record real API responses and replay them in tests.

```elixir
defmodule MyApp.LLM.RecordedResponses do
  @responses_dir "test/fixtures/llm_responses"

  def record(name, messages, opts) do
    result = MyApp.LLM.OpenAI.chat_completion(messages, opts)

    path = Path.join(@responses_dir, "#{name}.json")
    data = %{messages: messages, opts: opts, result: result}
    File.write!(path, Jason.encode!(data, pretty: true))

    result
  end

  def replay(name) do
    path = Path.join(@responses_dir, "#{name}.json")

    path
    |> File.read!()
    |> Jason.decode!()
    |> Map.get("result")
    |> atomize_result()
  end

  defp atomize_result(%{"ok" => value}), do: {:ok, value}
  defp atomize_result(%{"error" => reason}), do: {:error, reason}
end
```

### Property-Based Testing for Structured Output

When using Instructor, test that your schemas handle edge cases.

```elixir
defmodule MyApp.AI.Schemas.SentimentAnalysisTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "changeset rejects invalid confidence values" do
    check all confidence <- float(min: -10.0, max: 10.0),
              confidence < 0.0 or confidence > 1.0 do
      changeset =
        MyApp.AI.Schemas.SentimentAnalysis.changeset(
          %MyApp.AI.Schemas.SentimentAnalysis{},
          %{sentiment: :positive, confidence: confidence, reasoning: "test"}
        )

      refute changeset.valid?
    end
  end
end
```

## Production Considerations

A few hard-won lessons from running LLM features in production.

**Timeouts are not optional.** LLM APIs can hang. Set aggressive receive timeouts — 30 seconds is generous. Use Task.async_stream with timeouts for batch operations.

**Log prompts and responses.** When something goes wrong, you need to know exactly what you sent and what you received. Redact sensitive data, but log the structure.

**Monitor token usage.** Track tokens consumed per request, per user, per feature. Costs can spiral quickly. Build dashboards. Set alerts.

**Degrade gracefully.** When the LLM API is down or rate-limited, your feature should not error. Cache aggressively. Provide fallback behavior. Show users a helpful message, not a stack trace.

**Version your prompts.** Treat prompts like code. Store them in version control. When you change a prompt, you are changing behavior. Test accordingly.

## Conclusion

Elixir is not the obvious choice for AI features. That is precisely why it works so well.

The language's strengths — concurrency, fault tolerance, real-time capabilities — align perfectly with the operational demands of production AI systems. You spend less time fighting infrastructure and more time building features.

The ecosystem is maturing rapidly. Libraries like Instructor and openai_ex are production-ready. Phoenix LiveView makes streaming trivial. OTP supervision trees give you resilience that other languages require entire frameworks to achieve.

Python will remain the language of AI research. But for shipping AI-powered features to real users, Elixir deserves serious consideration.

---

**Claims to verify:**
- Library versions and APIs for openai_ex, anthropix, and instructor should be verified against current releases
- OpenAI and Anthropic API request/response formats should be validated against current API documentation
- Specific model names (gpt-4-turbo, claude-3-5-sonnet-20241022) should be verified for current availability
- Hammer and Cachex configuration options should be checked against current library documentation
