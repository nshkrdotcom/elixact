defmodule Schemix.Types do
  @moduledoc """
  Core type system for Schemix, providing basic and complex type definitions.
  """

  # Basic types
  def string, do: {:type, :string, []}
  def integer, do: {:type, :integer, []}
  def float, do: {:type, :float, []}
  def boolean, do: {:type, :boolean, []}

  # Basic type constructor
  def type(name) when is_atom(name) do
    case name do
      :string -> string()
      :integer -> integer()
      :float -> float()
      :boolean -> boolean()
      _ -> {:type, name, []}
    end
  end

  # Complex types
  def array(inner_type) when is_atom(inner_type) do
    {:array, inner_type, []}
  end

  def array({:type, _, _} = inner_type), do: {:array, inner_type, []}
  def array({:array, _, _} = inner_type), do: {:array, inner_type, []}
  def array({:map, _, _} = inner_type), do: {:array, inner_type, []}
  def array({:union, _, _} = inner_type), do: {:array, inner_type, []}

  def map(key_type, value_type) do
    key = if is_atom(key_type), do: type(key_type), else: key_type
    value = if is_atom(value_type), do: type(value_type), else: value_type
    {:map, {key, value}, []}
  end

  def union(types) when is_list(types), do: {:union, types, []}
  # Type reference
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
