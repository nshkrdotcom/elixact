defmodule Schemix.Types do
  @moduledoc """
  Core type system for Schemix, providing basic and complex type definitions.
  """

  # Basic types
  def string, do: {:type, :string, []}
  def integer, do: {:type, :integer, []}
  def float, do: {:type, :float, []}
  def boolean, do: {:type, :boolean, []}

  # Complex types
  def array(type), do: {:array, type, []}
  def map(key_type, value_type), do: {:map, {key_type, value_type}, []}
  def union(types), do: {:union, types, []}

  # Type modifiers
  def optional(type), do: {:optional, type}
  def required(type), do: {:required, type}

  # Type constraints
  def with_constraints(type, constraints) do
    case type do
      {:type, name, existing} -> {:type, name, existing ++ constraints}
      {kind, inner, existing} -> {kind, inner, existing ++ constraints}
    end
  end

  # Validation functions
  def validate(:string, value) when is_binary(value), do: {:ok, value}
  def validate(:integer, value) when is_integer(value), do: {:ok, value}
  def validate(:float, value) when is_float(value), do: {:ok, value}
  def validate(:boolean, value) when is_boolean(value), do: {:ok, value}

  def validate(type, value) do
    {:error, "#{inspect(value)} is not a valid #{inspect(type)}"}
  end
end
