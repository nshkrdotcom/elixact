defmodule Elixact.ValidationError do
  @moduledoc """
  Exception raised when schema validation fails.
  """

  defexception [:errors]

  @impl true
  def message(%{errors: errors}) do
    errors
    |> Enum.map(&Elixact.Error.format/1)
    |> Enum.join("\n")
  end
end
