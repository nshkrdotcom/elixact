defmodule Schemix.Error do
  @moduledoc """
  Structured error representation for Schemix validation errors.
  """

  @type t :: %__MODULE__{
          path: [atom() | String.t()],
          code: atom(),
          message: String.t()
        }

  defstruct [:path, :code, :message]

  @doc """
  Creates a new validation error.

  ## Parameters
    * `path` - Path to the field that caused the error
    * `code` - Error code identifying the type of error
    * `message` - Human-readable error message

  ## Example
      iex> Error.new([:user, :email], :format, "invalid email format")
      %Error{path: [:user, :email], code: :format, message: "invalid email format"}
  """
  def new(path, code, message) do
    %__MODULE__{
      path: List.wrap(path),
      code: code,
      message: message
    }
  end

  @doc """
  Formats an error into a human-readable string.

  ## Example
      iex> Error.format(%Error{path: [:user, :email], code: :format, message: "invalid format"})
      "user.email: invalid format"
  """
  def format(%__MODULE__{path: path, message: message}) do
    path_str = path |> Enum.map(&to_string/1) |> Enum.join(".")
    "#{path_str}: #{message}"
  end
end
