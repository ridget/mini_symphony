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
  @required_fields Enum.map(@enforce_keys, &Atom.to_string/1)

  @active_states ["todo", "in_progress"]

  defstruct [:id, :identifier, :title, :description, :state, priority: 99]

  def new(attrs) when is_map(attrs) do
    missing = Enum.filter(@required_fields, fn key -> !Map.has_key?(attrs, key) end)

    if missing == [] do
      {:ok, cast_to_struct(attrs)}
    else
      {:error, "missing the following fields #{Enum.join(missing, ", ")}"}
    end
  end

  def active_states, do: @active_states

  defp cast_to_struct(attrs) do
    allowed_keys = Map.keys(struct(__MODULE__, %{}))

    struct_data =
      for {k, v} <- attrs,
          key_atom = String.to_existing_atom(k),
          key_atom in allowed_keys,
          into: %{},
          do: {key_atom, v}

    struct!(__MODULE__, struct_data)
  end
end
