defmodule MiniSymphony.Llm.NoOp do
  @behaviour MiniSymphony.Llm

  @impl true
  def chat(_url, _model, _messages, _opts) do
    stubs = Process.get(:stub_responses)

    case stubs do
      [response | rest] when is_list(stubs) ->
        Process.put(:stub_responses, rest)
        response

      _ ->
        {:ok, %{"role" => "assistant", "content" => "The work is done."}}
    end
  end
end
