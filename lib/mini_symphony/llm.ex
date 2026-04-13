defmodule MiniSymphony.Llm do
  @moduledoc "Behaviour for LLM clients."

  @callback chat(url :: String.t(), model :: String.t(), messages :: [map()], opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
