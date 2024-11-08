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
    end
  end

  defmacro field(name, type, do: block) do
    quote do
      field_meta = %{
        name: unquote(name),
        type: unquote(handle_type(type)),
        description: nil,
        example: nil,
        required: false,
        optional: false,
        default: nil,
        constraints: []
      }

      var!(field_meta) = field_meta
      unquote(block)

      @fields {unquote(name), var!(field_meta)}
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

  defmacro required(bool) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :required, unquote(bool))
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

  defp handle_type({:union, types}) do
    quote do
      Types.union(unquote(types))
    end
  end

  defp handle_type(type) when is_atom(type) do
    quote do
      Types.type(unquote(type))
    end
  end

  # Configuration block
  defmacro config(do: block) do
    quote do
      config = %{
        title: nil,
        description: nil,
        strict: false,
        json_encoders: %{}
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

  defmacro strict(bool) do
    quote do
      var!(config) = Map.put(var!(config), :strict, unquote(bool))
    end
  end
end
