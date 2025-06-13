defmodule Elixact.ValidationError do
  @moduledoc """
  Exception raised when schema validation fails.

  This exception is raised when using the validate!/1 functions
  and validation fails, providing detailed error information.
  """

  @type t :: %__MODULE__{
          errors: [Elixact.Error.t()]
        }

  @enforce_keys [:errors]
  defexception [:errors]

  @impl true
  @doc """
  Formats the validation errors into a human-readable message.

  ## Parameters
    * `exception` - The ValidationError exception struct

  ## Returns
    * A formatted error message string

  ## Examples

      iex> errors = [%Elixact.Error{path: [:name], code: :required, message: "field is required"}]
      iex> exception = %Elixact.ValidationError{errors: errors}
      iex> Elixact.ValidationError.message(exception)
      "name: field is required"
  """
  @spec message(t()) :: String.t()
  def message(%{errors: errors}) do
    errors
    |> Enum.map_join("\n", &Elixact.Error.format/1)
  end
end
