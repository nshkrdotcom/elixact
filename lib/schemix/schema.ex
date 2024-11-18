defmodule Schemix.Schema do
  @moduledoc """
  Schema DSL for defining data schemas with validation rules and metadata.
  """

  alias Schemix.Types

  defmacro schema(description \\ nil, do: block) do
    quote do
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :config, [])

      @schema_description unquote(description)

      unquote(block)

      # Generate schema metadata at compile time
      def __schema__(:description), do: @schema_description
      def __schema__(:fields), do: @fields
      def __schema__(:config), do: @config

      # Generate validation functions
      def validate(data) do
        Schemix.Validator.validate_schema(__MODULE__, data)
      end

      def validate!(data) do
        case validate(data) do
          {:ok, validated} -> validated
          {:error, errors} -> raise Schemix.ValidationError, errors: errors
        end
      end
    end
  end

  defmacro min_length(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:min_length, unquote(value)} | current_constraints
        ])
    end
  end

  defmacro max_length(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:max_length, unquote(value)} | current_constraints
        ])
    end
  end

  defmacro min_items(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:min_items, unquote(value)} | current_constraints
        ])
    end
  end

  defmacro max_items(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:max_items, unquote(value)} | current_constraints
        ])
    end
  end

  defmacro gt(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:gt, unquote(value)} | current_constraints])
    end
  end

  defmacro lt(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:lt, unquote(value)} | current_constraints])
    end
  end

  defmacro gteq(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:gteq, unquote(value)} | current_constraints])
    end
  end

  defmacro lteq(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:lteq, unquote(value)} | current_constraints])
    end
  end

  defmacro format(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:format, unquote(value)} | current_constraints])
    end
  end

  # Field macro remains the same
  defmacro field(name, type, do: block) do
    quote do
      field_meta = %Schemix.FieldMeta{
        name: unquote(name),
        type: unquote(handle_type(type)),
        constraints: []
      }

      var!(field_meta) = field_meta
      unquote(block)

      # Apply constraints to the type
      final_type =
        case var!(field_meta).type do
          {:type, type_name, _} ->
            {:type, type_name, Enum.reverse(var!(field_meta).constraints)}

          {kind, inner, _} ->
            {kind, inner, Enum.reverse(var!(field_meta).constraints)}

          other ->
            other
        end

      final_meta = Map.put(var!(field_meta), :type, final_type)
      @fields {unquote(name), final_meta}
    end
  end

  # Field metadata setters
  defmacro description(text) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :description, unquote(text))
    end
  end

  defmacro example(value) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :example, unquote(value))
    end
  end

  defmacro examples(values) when is_list(values) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :examples, unquote(values))
    end
  end

  defmacro required(bool) do
    quote do
      var!(field_meta) =
        var!(field_meta)
        |> Map.put(:required, unquote(bool))
        |> Map.put(:optional, not unquote(bool))
    end
  end

  defmacro optional(bool) do
    quote do
      var!(field_meta) =
        var!(field_meta)
        |> Map.put(:optional, unquote(bool))
        |> Map.put(:required, not unquote(bool))
    end
  end

  defmacro default(value) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :default, unquote(value))
    end
  end

  # Handle type definitions
  defp handle_type({:array, type}) do
    quote do
      Types.array(unquote(type))
    end
  end

  # Handle map types
  defp handle_type({:map, {key_type, value_type}}) do
    normalized_key = handle_type(key_type)
    normalized_value = handle_type(value_type)
    quote do
      Types.map(unquote(normalized_key), unquote(normalized_value))
    end
  end

  # Handle union types
  defp handle_type({:union, types}) do
    quote do
      Types.union(unquote(types))
    end
  end

  defp handle_type({:__aliases__, _, _} = module_alias) do
    quote do
      unquote(module_alias)
    end
  end

  # Handle module references and other atoms
  defp handle_type(module) when is_atom(module) do
    cond do
      Code.ensure_loaded?(module) && function_exported?(module, :__schema__, 1) ->
        {:ref, module}

      true ->
        quote do
          Types.type(unquote(module))
        end
    end
  end

  # Configuration block
  defmacro config(do: block) do
    quote do
      config = %{
        title: nil,
        description: nil,
        strict: false
      }

      var!(config) = config
      unquote(block)

      @config var!(config)
    end
  end

  # Config setters
  defmacro title(text) do
    quote do
      var!(config) = Map.put(var!(config), :title, unquote(text))
    end
  end

  defmacro config_description(text) do
    quote do
      var!(config) = Map.put(var!(config), :description, unquote(text))
    end
  end

  defmacro strict(bool) do
    quote do
      var!(config) = Map.put(var!(config), :strict, unquote(bool))
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __schema__(:description), do: @schema_description
      def __schema__(:fields), do: @fields
      def __schema__(:validations), do: @validations
      def __schema__(:config), do: @config

      @doc """
      Validates data against this schema.

      Returns `{:ok, validated_data}` or `{:error, errors}`.
      """
      def validate(data) do
        Schemix.Validator.validate_schema(__MODULE__, data)
      end

      @doc """
      Validates data against this schema, raising on error.

      Returns validated data or raises Schemix.ValidationError.
      """
      def validate!(data) do
        case validate(data) do
          {:ok, validated} -> validated
          {:error, errors} -> raise Schemix.ValidationError, errors: errors
        end
      end
    end
  end
end
