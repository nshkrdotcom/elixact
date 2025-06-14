defmodule Elixact.Types do
  @moduledoc """
  Core type system for Elixact schemas.

  Provides functions for defining and working with types:
  - Basic types (:string, :integer, :float, :boolean)
  - Complex types (arrays, maps, unions)
  - Type constraints
  - Type validation
  - Type coercion

  ## Basic Types

      # String type
      Types.string()

      # Integer type with constraints
      Types.integer()
      |> Types.with_constraints(gt: 0, lt: 100)

  ## Complex Types

      # Array of strings
      Types.array(Types.string())

      # Map with string keys and integer values
      Types.map(Types.string(), Types.integer())

      # Union of types
      Types.union([Types.string(), Types.integer()])

  ## Type Constraints

  Constraints can be added to types to enforce additional rules:

      Types.string()
      |> Types.with_constraints([
        min_length: 3,
        max_length: 10,
        format: ~r/^[a-z]+$/
      ])
  """

  @type type_definition ::
          {:type, atom(), [any()]}
          | {:array, type_definition, [any()]}
          | {:map, {type_definition, type_definition}, [any()]}
          | {:union, [type_definition], [any()]}
          | {:ref, atom()}

  alias Elixact.Error

  # Basic types
  @spec string() :: {:type, :string, []}
  def string, do: {:type, :string, []}

  @spec integer() :: {:type, :integer, []}
  def integer, do: {:type, :integer, []}

  @spec float() :: {:type, :float, []}
  def float, do: {:type, :float, []}

  @spec boolean() :: {:type, :boolean, []}
  def boolean, do: {:type, :boolean, []}

  # Basic type constructor
  @spec type(atom()) :: {:type, atom(), []}
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
  @spec array(type_definition()) :: {:array, type_definition(), []}
  def array(inner_type) do
    normalized = normalize_type(inner_type)
    {:array, normalized, []}
  end

  @spec map(type_definition(), type_definition()) ::
          {:map, {type_definition(), type_definition()}, []}
  def map(key_type, value_type) do
    normalized_key = normalize_type(key_type)
    normalized_value = normalize_type(value_type)
    {:map, {normalized_key, normalized_value}, []}
  end

  @spec union([type_definition()]) :: {:union, [type_definition()], []}
  def union(types) when is_list(types), do: {:union, types, []}

  # Type reference
  @spec ref(atom()) :: {:ref, atom()}
  def ref(schema), do: {:ref, schema}

  @spec tuple([type_definition()]) :: {:tuple, [type_definition()]}
  def tuple(types) when is_list(types), do: {:tuple, types}

  # Helper to normalize type definitions
  @doc """
  Normalizes a type definition to the standard internal format.

  ## Parameters
    * `type` - The type definition to normalize

  ## Returns
    * A normalized type definition tuple

  ## Examples

      iex> Elixact.Types.normalize_type(:string)
      {:type, :string, []}

      iex> Elixact.Types.normalize_type({:array, :integer})
      {:array, {:type, :integer, []}, []}
  """
  @spec normalize_type(term()) :: type_definition()
  def normalize_type({:map, {key_type, value_type}}) do
    {:map, {normalize_type(key_type), normalize_type(value_type)}, []}
  end

  def normalize_type({:union, types}) when is_list(types) do
    {:union, Enum.map(types, &normalize_type/1), []}
  end

  def normalize_type({:tuple, types}) when is_list(types) do
    {:tuple,
     Enum.map(types, fn type ->
       cond do
         is_atom(type) and type in [:string, :integer, :float, :boolean, :any, :atom] ->
           {:type, type, []}

         is_atom(type) and not is_schema_module(type) ->
           type

         true ->
           normalize_type(type)
       end
     end)}
  end

  def normalize_type(type) when is_atom(type) do
    cond do
      type in [:string, :integer, :float, :boolean, :any, :atom] ->
        {:type, type, []}

      Code.ensure_loaded?(type) and function_exported?(type, :__schema__, 1) ->
        {:ref, type}

      true ->
        type
    end
  end

  def normalize_type(other), do: other

  defp is_schema_module(atom) when is_atom(atom) do
    Code.ensure_loaded?(atom) and function_exported?(atom, :type_definition, 0)
  end

  @doc """
  Coerces a value to the specified type.

  ## Parameters
    * `type` - The target type to coerce to
    * `value` - The value to coerce

  ## Returns
    * `{:ok, coerced_value}` on success
    * `{:error, reason}` on failure

  ## Examples

      iex> Elixact.Types.coerce(:string, 42)
      {:ok, "42"}

      iex> Elixact.Types.coerce(:integer, "123")
      {:ok, 123}

      iex> Elixact.Types.coerce(:integer, "abc")
      {:error, "invalid integer format"}
  """
  @spec coerce(atom(), term()) :: {:ok, term()} | {:error, String.t()}
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

  @doc """
  Adds constraints to a type definition.

  ## Parameters
    * `type` - The type definition to add constraints to
    * `constraints` - List of constraints to add

  ## Returns
    * Updated type definition with constraints

  ## Examples

      iex> string_type = Elixact.Types.string()
      iex> Elixact.Types.with_constraints(string_type, [min_length: 3, max_length: 10])
      {:type, :string, [min_length: 3, max_length: 10]}
  """
  @spec with_constraints(type_definition(), [term()]) :: {atom(), term(), [term()]}
  def with_constraints(type, constraints) do
    case type do
      {:type, name, existing} -> {:type, name, existing ++ constraints}
      {kind, inner, existing} -> {kind, inner, existing ++ constraints}
    end
  end

  @doc """
  Validates a value against a basic type.

  ## Parameters
    * `type` - The type to validate against
    * `value` - The value to validate

  ## Returns
    * `{:ok, value}` if validation succeeds
    * `{:error, Elixact.Error.t()}` if validation fails

  ## Examples

      iex> Elixact.Types.validate(:string, "hello")
      {:ok, "hello"}

      iex> Elixact.Types.validate(:integer, "not a number")
      {:error, %Elixact.Error{path: [], code: :type, message: "expected integer, got \"not a number\""}}
  """
  @spec validate(atom(), term()) :: {:ok, term()} | {:error, Elixact.Error.t()}
  def validate(:string, value) when is_binary(value), do: {:ok, value}

  def validate(:string, value),
    do: {:error, Error.new([], :type, "expected string, got #{inspect(value)}")}

  def validate(:integer, value) when is_integer(value), do: {:ok, value}

  def validate(:integer, value),
    do: {:error, Error.new([], :type, "expected integer, got #{inspect(value)}")}

  def validate(:float, value) when is_float(value), do: {:ok, value}

  def validate(:float, value),
    do: {:error, Error.new([], :type, "expected float, got #{inspect(value)}")}

  def validate(:boolean, value) when is_boolean(value), do: {:ok, value}

  def validate(:boolean, value),
    do: {:error, Error.new([], :type, "expected boolean, got #{inspect(value)}")}

  def validate(:atom, value) when is_atom(value) and not is_nil(value), do: {:ok, value}

  def validate(:atom, value),
    do: {:error, Error.new([], :type, "expected atom, got #{inspect(value)}")}

  def validate(:any, value), do: {:ok, value}

  def validate(type, value) when is_atom(type),
    do: {:error, Error.new([], :type, "#{inspect(value)} is not a valid #{inspect(type)}")}

  def validate(type, value), do: Elixact.Validator.validate(type, value, [])
end
