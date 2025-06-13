defmodule Elixact.Type do
  @moduledoc """
  Behaviour and macros for defining custom types.

  This module provides the behaviour and utility functions for creating
  custom types in Elixact schemas with validation and coercion capabilities.
  """

  @type coerce_function :: (term() -> {:ok, term()} | {:error, term()})
  @type coerce_rule :: coerce_function() | {module(), atom()} | nil

  @callback type_definition() :: Elixact.Types.type_definition()
  @callback json_schema() :: map()
  @callback validate(term()) :: {:ok, term()} | {:error, term()}
  @callback coerce_rule() :: coerce_rule()
  @callback custom_rules() :: [atom()]

  @optional_callbacks coerce_rule: 0, custom_rules: 0

  defmacro __using__(_opts) do
    quote do
      @behaviour Elixact.Type
      import Elixact.Types

      # Import types from Elixact.Type
      @type coerce_function :: Elixact.Type.coerce_function()
      @type coerce_rule :: Elixact.Type.coerce_rule()

      Module.register_attribute(__MODULE__, :type_metadata, accumulate: true)

      def metadata, do: @type_metadata

      def validate(value, path \\ []) do
        with {:ok, coerced} <- maybe_coerce(value),
             {:ok, validated} <- validate_type(coerced, path) do
          validate_custom_rules(validated, path)
        end
      end

      defp validate_type(value, path) do
        type = type_definition()
        Elixact.Validator.validate(type, value, path)
      end

      @spec maybe_coerce(term()) :: {:ok, term()} | {:error, term()}
      defp maybe_coerce(value) do
        # Simple implementation - most custom types don't need coercion
        {:ok, value}
      end

      defp validate_custom_rules(value, path) do
        Enum.reduce_while(custom_rules(), {:ok, value}, fn rule, {:ok, val} ->
          case apply(__MODULE__, rule, [val]) do
            true -> {:cont, {:ok, val}}
            false -> {:halt, {:error, "failed custom rule: #{rule}"}}
            {:error, reason} -> {:halt, {:error, reason, path: path}}
          end
        end)
      end

      # Default implementations that can be overridden
      @spec coerce_rule() :: coerce_rule()
      def coerce_rule, do: nil

      @spec custom_rules() :: [atom()]
      def custom_rules, do: []

      defoverridable coerce_rule: 0, custom_rules: 0
    end
  end
end
