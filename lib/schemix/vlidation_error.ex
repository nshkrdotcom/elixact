defmodule Schemix.ValidationError do
  @moduledoc """
  Exception raised when schema validation fails.
  """

  defexception [:errors]

  @impl true
  def message(%{errors: errors}) do
    errors
    |> Enum.map(&Schemix.Error.format/1)
    |> Enum.join("\n")
  end
end
