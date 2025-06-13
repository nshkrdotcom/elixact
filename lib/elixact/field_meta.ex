defmodule Elixact.FieldMeta do
  @moduledoc """
  Struct for field metadata in Elixact schemas.

  This module defines the structure and types for field metadata used
  throughout the Elixact schema system.
  """

  @enforce_keys [:name, :type, :required]
  defstruct [
    :name,
    :type,
    :description,
    :example,
    :examples,
    :required,
    :optional,
    :default,
    :constraints
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: Elixact.Types.type_definition(),
          description: String.t() | nil,
          example: term() | nil,
          examples: [term()] | nil,
          required: boolean(),
          optional: boolean() | nil,
          default: term() | nil,
          constraints: [term()] | nil
        }
end
