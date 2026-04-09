defmodule MiniSymphony.Issue do
  @moduledoc """
  A unit of work for the orchestrator
  """

  @type t :: %__MODULE__{
          id: String.t(),
          identifier: String.t(),
          title: String.t(),
          description: String.t() | nil,
          state: String.t(),
          priority: integer()
        }

  @enforce_keys [:id, :identifier, :title, :state]

  defstruct [:id, :identifier, :title, :description, :state, priority: 99]
end
