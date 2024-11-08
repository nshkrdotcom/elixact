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

  def ref(schema), do: {:ref, schema}

  # Add coercion helpers
  def coerce(:string, value) when is_integer(value), do: {:ok, Integer.to_string(value)}
  def coerce(:string, value) when is_float(value), do: {:ok, Float.to_string(value)}

  def coerce(:integer, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "invalid integer format"}
    end
  end

  def coerce(:float, value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, "invalid float format"}
    end
  end

  def coerce(_, value), do: {:error, "cannot coerce #{inspect(value)}"}

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
