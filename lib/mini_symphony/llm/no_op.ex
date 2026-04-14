defmodule MiniSymphony.Llm.NoOp do
  @behaviour MiniSymphony.Llm

  @impl true
  def chat(_url, _model, _messages, _opts) do
    case Process.get(:stub_responses) do
      [response | rest] ->
        Process.put(:stub_responses, rest)
        response

      [] ->
        {:ok, %{"role" => "assistant", "content" => "Default stub response."}}
    end
  end
end
