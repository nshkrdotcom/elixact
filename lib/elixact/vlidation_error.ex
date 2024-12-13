defmodule Elixact.ValidationError do
  @moduledoc """
  Exception raised when schema validation fails.
  """

  defexception [:errors]

  @impl true
  def message(%{errors: errors}) do
    errors
    |> Enum.map_join("\n", &Elixact.Error.format/1)
  end
end
