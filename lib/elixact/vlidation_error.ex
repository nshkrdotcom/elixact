defmodule Elixact.ValidationError do
  @moduledoc """
  Exception raised when schema validation fails.

  This exception is raised when using the validate!/1 functions
  and validation fails, providing detailed error information.
  """

  @type t :: %__MODULE__{
          errors: [Elixact.Error.t()]
        }

  defexception [:errors]

  @impl true
  @spec message(t()) :: String.t()
  def message(%{errors: errors}) do
    errors
    |> Enum.map_join("\n", &Elixact.Error.format/1)
  end
end
