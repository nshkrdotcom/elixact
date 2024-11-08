defmodule Schemix.Validator do
  @moduledoc """
  Validates values against type definitions.
  """

  def validate(type, value) do
    case type do
      {:type, name, constraints} ->
        with {:ok, validated} <- Schemix.Types.validate(name, value) do
          apply_constraints(validated, constraints)
        end

      {:array, inner_type, constraints} ->
        validate_array(value, inner_type, constraints)

      {:map, {key_type, value_type}, constraints} ->
        validate_map(value, key_type, value_type, constraints)

      {:union, types, _constraints} ->
        validate_union(value, types)
    end
  end

  defp apply_constraints(value, []), do: {:ok, value}

  defp apply_constraints(value, [{constraint, constraint_value} | rest]) do
    case apply_constraint(constraint, value, constraint_value) do
      true -> apply_constraints(value, rest)
      false -> {:error, "failed #{constraint} constraint"}
    end
  end

  # String constraints
  defp apply_constraint(:min_length, value, min) when is_binary(value) do
    String.length(value) >= min
  end

  defp apply_constraint(:max_length, value, max) when is_binary(value) do
    String.length(value) <= max
  end

  # List constraints
  defp apply_constraint(:min_items, value, min) when is_list(value) do
    length(value) >= min
  end

  defp apply_constraint(:max_items, value, max) when is_list(value) do
    length(value) <= max
  end

  # Number constraints
  defp apply_constraint(:gt, value, min) when is_number(value) do
    value > min
  end

  defp apply_constraint(:lt, value, max) when is_number(value) do
    value < max
  end

  defp apply_constraint(:gteq, value, min) when is_number(value) do
    value >= min
  end

  defp apply_constraint(:lteq, value, max) when is_number(value) do
    value <= max
  end

  # Map constraints
  defp apply_constraint(:size?, value, size) when is_map(value) do
    map_size(value) == size
  end

  # Format constraint for strings
  defp apply_constraint(:format, value, regex) when is_binary(value) do
    Regex.match?(regex, value)
  end

  # Array validation
  defp validate_array(value, _type, _constraints) when not is_list(value) do
    {:error, "expected array, got #{inspect(value)}"}
  end

  defp validate_array(value, type, constraints) do
    results = Enum.map(value, &validate(type, &1))

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      validated_array = Enum.map(results, fn {:ok, val} -> val end)
      apply_constraints(validated_array, constraints)
    else
      {:error, "invalid array elements"}
    end
  end

  # Map validation
  defp validate_map(value, key_type, value_type, constraints) when is_map(value) do
    key_results =
      Enum.map(value, fn {k, v} ->
        with {:ok, validated_key} <- validate(key_type, k),
             {:ok, validated_value} <- validate(value_type, v) do
          {:ok, {validated_key, validated_value}}
        end
      end)

    if Enum.all?(key_results, &match?({:ok, _}, &1)) do
      validated_map = Map.new(Enum.map(key_results, fn {:ok, kv} -> kv end))
      apply_constraints(validated_map, constraints)
    else
      {:error, "invalid map structure"}
    end
  end

  defp validate_map(value, _key_type, _value_type, _constraints) do
    {:error, "expected map, got #{inspect(value)}"}
  end

  # Union validation
  defp validate_union(value, types) do
    Enum.reduce_while(types, {:error, "no matching type"}, fn type, acc ->
      case validate(type, value) do
        {:ok, validated} -> {:halt, {:ok, validated}}
        _ -> {:cont, acc}
      end
    end)
  end
end
