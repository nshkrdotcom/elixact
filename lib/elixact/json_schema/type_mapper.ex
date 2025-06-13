defmodule Elixact.JsonSchema.TypeMapper do
  @moduledoc """
  Converts Elixact type definitions to JSON Schema type definitions.

  This module handles the conversion between Elixact's internal type system
  and JSON Schema representations, including complex types and constraints.
  """

  alias Elixact.JsonSchema.ReferenceStore

  @spec to_json_schema(Elixact.Types.type_definition() | module(), pid() | nil) :: map()
  def to_json_schema(type, store \\ nil)

  def to_json_schema(type, store) do
    cond do
      match?({:ref, _}, type) ->
        handle_schema_reference(type, store)

      is_atom(type) and custom_type?(type) ->
        apply_type_module(type)

      match?({:__aliases__, _, _}, type) ->
        module = Macro.expand(type, __ENV__)

        if schema_module?(module) do
          handle_schema_reference({:ref, module}, store)
        else
          apply_type_module(module)
        end

      true ->
        normalized_type = normalize_type(type)
        convert_normalized_type(normalized_type, store)
    end
  end

  @spec schema_module?(module()) :: boolean()
  defp schema_module?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1)
  end

  @spec handle_schema_reference({:ref, atom()}, pid()) :: %{String.t() => String.t()}
  defp handle_schema_reference({:ref, module}, store) when is_atom(module) do
    if store do
      ReferenceStore.add_reference(store, module)
      %{"$ref" => ReferenceStore.ref_path(module)}
    else
      raise "Schema reference #{inspect(module)} requires a reference store"
    end
  end

  @spec apply_type_module(module()) :: map()
  defp apply_type_module(module) do
    if custom_type?(module) do
      module.json_schema()
    else
      raise "Module #{inspect(module)} is not a valid Elixact type"
    end
  end

  @spec custom_type?(module()) :: boolean()
  defp custom_type?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :json_schema, 0)
  end

  # Normalize type definitions
  @spec normalize_type(term()) :: Elixact.Types.type_definition()
  defp normalize_type(type) when is_atom(type) do
    if schema_module?(type) do
      {:ref, type}
    else
      {:type, type, []}
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
  @spec convert_normalized_type(Elixact.Types.type_definition(), pid() | nil) :: map()
  defp convert_normalized_type(type, store) do
    if match?({:ref, _}, type) and schema_module?(type |> elem(1)) do
      handle_schema_reference(type, store)
    else
      convert_type(type, store)
    end
  end

  @spec convert_type(Elixact.Types.type_definition(), pid() | nil) :: map()
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
  @spec map_basic_type(atom()) :: %{String.t() => String.t()}
  defp map_basic_type(:string), do: %{"type" => "string"}
  defp map_basic_type(:integer), do: %{"type" => "integer"}
  defp map_basic_type(:float), do: %{"type" => "number"}
  defp map_basic_type(:boolean), do: %{"type" => "boolean"}

  defp map_basic_type(module) when is_atom(module) do
    name = module |> Module.split() |> List.last()
    %{"$ref" => "#/definitions/#{name}"}
  end

  # Array type mapping
  @spec map_array_type(Elixact.Types.type_definition(), [term()], pid() | nil) :: map()
  defp map_array_type(inner_type, constraints, store) do
    base = %{
      "type" => "array",
      "items" => to_json_schema(inner_type, store)
    }

    apply_constraints(base, constraints)
  end

  # Map type mapping
  @spec map_map_type(
          Elixact.Types.type_definition(),
          Elixact.Types.type_definition(),
          [term()],
          pid() | nil
        ) :: map()
  defp map_map_type(_key_type, value_type, constraints, store) do
    base = %{
      "type" => "object",
      "additionalProperties" => to_json_schema(value_type, store)
    }

    apply_constraints(base, constraints)
  end

  # Union type mapping
  @spec map_union_type([Elixact.Types.type_definition()], [term()], pid() | nil) :: map()
  defp map_union_type(types, constraints, store) do
    base = %{
      "oneOf" => Enum.map(types, &to_json_schema(&1, store))
    }

    apply_constraints(base, constraints)
  end

  # Constraint mapping
  @spec apply_constraints(map(), [term()]) :: map()
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
