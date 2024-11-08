defmodule Schemix.JsonSchema.TypeMapper do
  @moduledoc """
  Converts Schemix type definitions to JSON Schema type definitions.
  """

  alias Schemix.JsonSchema.ReferenceStore

  def to_json_schema(type, store \\ nil)

  def to_json_schema(type, store) do
    cond do
      is_atom(type) and schema_module?(type) ->
        handle_schema_reference(type, store)

      is_atom(type) and custom_type?(type) ->
        apply_type_module(type)

      match?({:__aliases__, _, _}, type) ->
        module = Macro.expand(type, __ENV__)

        if schema_module?(module) do
          handle_schema_reference(module, store)
        else
          apply_type_module(module)
        end

      true ->
        normalized_type = normalize_type(type)
        convert_normalized_type(normalized_type, store)
    end
  end

  defp schema_module?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1)
  end

  defp handle_schema_reference(module, store) when is_atom(module) do
    if store do
      ReferenceStore.add_reference(store, module)
      %{"$ref" => ReferenceStore.ref_path(module)}
    else
      raise "Schema reference #{inspect(module)} requires a reference store"
    end
  end

  defp apply_type_module(module) do
    if custom_type?(module) do
      module.json_schema()
    else
      raise "Module #{inspect(module)} is not a valid Schemix type"
    end
  end

  defp custom_type?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :json_schema, 0)
  end

  # Normalize type definitions
  defp normalize_type(type) when is_atom(type) do
    cond do
      schema_module?(type) -> type
      true -> {:type, type, []}
    end
  end

  defp normalize_type({:array, type}) do
    {:array, normalize_type(type), []}
  end

  defp normalize_type({:array, type, constraints}) do
    {:array, normalize_type(type), constraints}
  end

  defp normalize_type({:map, {key_type, value_type}}) do
    {:map, {normalize_type(key_type), normalize_type(value_type)}, []}
  end

  defp normalize_type({:union, types}) when is_list(types) do
    {:union, Enum.map(types, &normalize_type/1), []}
  end

  defp normalize_type(type), do: type

  # Convert normalized types
  defp convert_normalized_type(type, store) do
    cond do
      is_atom(type) and schema_module?(type) ->
        handle_schema_reference(type, store)

      true ->
        convert_type(type, store)
    end
  end

  defp convert_type({:type, base_type, constraints}, _store) do
    map_basic_type(base_type)
    |> apply_constraints(constraints)
  end

  defp convert_type({:array, inner_type, constraints}, store) do
    map_array_type(inner_type, constraints, store)
  end

  defp convert_type({:map, {key_type, value_type}, constraints}, store) do
    map_map_type(key_type, value_type, constraints, store)
  end

  defp convert_type({:union, types, constraints}, store) do
    map_union_type(types, constraints, store)
  end

  # Basic type mapping
  defp map_basic_type(:string), do: %{"type" => "string"}
  defp map_basic_type(:integer), do: %{"type" => "integer"}
  defp map_basic_type(:float), do: %{"type" => "number"}
  defp map_basic_type(:boolean), do: %{"type" => "boolean"}

  # Array type mapping
  defp map_array_type(inner_type, constraints, store) do
    base = %{
      "type" => "array",
      "items" => to_json_schema(inner_type, store)
    }

    apply_constraints(base, constraints)
  end

  # Map type mapping
  defp map_map_type(_key_type, value_type, constraints, store) do
    base = %{
      "type" => "object",
      "additionalProperties" => to_json_schema(value_type, store)
    }

    apply_constraints(base, constraints)
  end

  # Union type mapping
  defp map_union_type(types, constraints, store) do
    base = %{
      "oneOf" => Enum.map(types, &to_json_schema(&1, store))
    }

    apply_constraints(base, constraints)
  end

  # Constraint mapping
  defp apply_constraints(schema, constraints) do
    Enum.reduce(constraints, schema, fn
      {:min_length, value}, acc -> Map.put(acc, "minLength", value)
      {:max_length, value}, acc -> Map.put(acc, "maxLength", value)
      {:min_items, value}, acc -> Map.put(acc, "minItems", value)
      {:max_items, value}, acc -> Map.put(acc, "maxItems", value)
      {:gt, value}, acc -> Map.put(acc, "exclusiveMinimum", value)
      {:lt, value}, acc -> Map.put(acc, "exclusiveMaximum", value)
      {:gteq, value}, acc -> Map.put(acc, "minimum", value)
      {:lteq, value}, acc -> Map.put(acc, "maximum", value)
      {:format, %Regex{} = regex}, acc -> Map.put(acc, "pattern", Regex.source(regex))
      _, acc -> acc
    end)
  end
end
