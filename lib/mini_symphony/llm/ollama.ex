defmodule MiniSymphony.Llm.Ollama do
  def chat(url, model, messages, opts \\ []) do
    tools = Keyword.get(opts, :tools, [])
    body = %{model: model, messages: messages, stream: false}
    body = if tools != [], do: Map.put(body, :tools, tools), else: body

    case Req.post(url <> "/api/chat", json: body, receive_timeout: 120_000) do
      {:ok, %Req.Response{status: 200, body: %{"message" => msg}}} ->
        {:ok, msg}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:connection_error, exception}}
    end
  end

  def health_check(url) do
    case Req.get(url <> "/api/tags", receive_timeout: 120_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:error, exception} ->
        {:error, {:connection_error, exception}}
    end
  end
end
