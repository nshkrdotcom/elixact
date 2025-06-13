defmodule Elixact.Validator do
  @moduledoc """
  Validates values against type definitions and schemas.

  This module provides the core validation logic for Elixact schemas,
  handling field validation, constraints, and error reporting.
  """

  alias Elixact.Error

  @type validation_result :: {:ok, term()} | {:error, Error.t() | [Error.t()]}
  @type validation_path :: [atom() | String.t() | integer()]

  @doc """
  Validates data against a schema module, checking for required fields,
  field-level validations, and strict mode constraints if enabled.

  ## Parameters
    * `schema` - Schema module to validate against
    * `data` - Data to validate (map)
    * `path` - Current validation path for error messages (defaults to `[]`)

  ## Returns
    * `{:ok, validated_data}` on success
    * `{:error, errors}` on validation failures

  ## Examples

      iex> defmodule TestSchema do
      ...>   use Elixact
      ...>   schema do
      ...>     field :name, :string
      ...>   end
      ...> end
      iex> Elixact.Validator.validate_schema(TestSchema, %{name: "John"})
      {:ok, %{name: "John"}}
  """
  @spec validate_schema(module(), map(), validation_path()) :: validation_result()
  def validate_schema(schema, data, path \\ []) when is_atom(schema) do
    fields = schema.__schema__(:fields)
    config = schema.__schema__(:config) || %{}

    with :ok <- validate_required_fields(fields, data, path),
         {:ok, validated} <- validate_fields(fields, data, path),
         :ok <- validate_strict(config, validated, data, path) do
      {:ok, validated}
    end
  end

  @spec validate_required_fields([{atom(), Elixact.FieldMeta.t()}], map(), validation_path()) ::
          :ok | {:error, Error.t()}
  defp validate_required_fields(fields, data, path) do
    required_fields = for {name, meta} <- fields, meta.required, do: name

    case Enum.find(required_fields, fn field ->
           not (Map.has_key?(data, field) or Map.has_key?(data, Atom.to_string(field)))
         end) do
      nil -> :ok
      field -> {:error, Error.new([field | path], :required, "field is required")}
    end
  end

  @spec validate_fields([{atom(), Elixact.FieldMeta.t()}], map(), validation_path()) ::
          {:ok, map()} | {:error, Error.t()}
  defp validate_fields(fields, data, path) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {name, meta}, {:ok, acc} ->
      field_path = path ++ [name]
      value = Map.get(data, name) || Map.get(data, Atom.to_string(name))

      case {value, meta} do
        {nil, %{default: default}} ->
          {:cont, {:ok, Map.put(acc, name, default)}}

        {nil, %{required: false}} ->
          {:cont, {:ok, acc}}

        {nil, _} ->
          {:halt, {:error, Error.new(field_path, :required, "field is required")}}

        {value, _} ->
          case validate(meta.type, value, field_path) do
            {:ok, validated} -> {:cont, {:ok, Map.put(acc, name, validated)}}
            {:error, errors} -> {:halt, {:error, errors}}
          end
      end
    end)
  end

  @spec validate_strict(map(), map(), map(), validation_path()) :: :ok | {:error, Error.t()}
  defp validate_strict(%{strict: true}, validated, original, path) do
    case Map.keys(original) -- Map.keys(validated) do
      [] ->
        :ok

      extra ->
        {:error, Error.new(path, :additional_properties, "unknown fields: #{inspect(extra)}")}
    end
  end

  defp validate_strict(_, _, _, _), do: :ok

  @doc """
  Validates a value against a type definition.

  ## Parameters
    * `type` - The type definition or schema module to validate against
    * `value` - The value to validate
    * `path` - Current validation path for error messages (defaults to `[]`)

  ## Returns
    * `{:ok, validated_value}` on success
    * `{:error, errors}` on validation failures

  ## Examples

      iex> Elixact.Validator.validate({:type, :string, []}, "hello")
      {:ok, "hello"}

      iex> Elixact.Validator.validate({:type, :integer, []}, "not a number")
      {:error, %Elixact.Error{...}}
  """
  @spec validate(Elixact.Types.type_definition() | module(), term(), validation_path()) ::
          validation_result()
  def validate(type, value, path \\ [])

  def validate({:ref, schema}, value, path) when is_atom(schema) do
    validate_schema(schema, value, path)
  end

  def validate(schema, value, path) when is_atom(schema) do
    cond do
      # Reference a Schema module
      Code.ensure_loaded?(schema) and function_exported?(schema, :__schema__, 1) ->
        validate_schema(schema, value, path)

      # Custom type
      Code.ensure_loaded?(schema) and function_exported?(schema, :type_definition, 0) ->
        schema.validate(value, path)

      true ->
        raise ArgumentError, "invalid schema: #{inspect(schema)}"
    end
  end

  def validate({:type, name, constraints}, value, path) do
    case Elixact.Types.validate(name, value) do
      {:ok, validated} -> apply_constraints(validated, constraints, path)
      {:error, error} -> {:error, %{error | path: path ++ error.path}}
    end
  end

  def validate({:array, inner_type, constraints}, value, path) do
    if is_list(value) do
      validate_array_items(value, inner_type, constraints, path)
    else
      {:error, [Error.new(path, :type, "expected array, got #{inspect(value)}")]}
    end
  end

  def validate({:map, {key_type, value_type}, constraints}, value, path) do
    validate_map(value, key_type, value_type, constraints, path)
  end

  def validate({:union, types, _constraints}, value, path) do
    validate_union(value, types, path)
  end

  @spec apply_constraints(term(), [term()], validation_path()) :: validation_result()
  defp apply_constraints(value, constraints, path) do
    Enum.reduce_while(constraints, {:ok, value}, fn
      {constraint, constraint_value}, {:ok, val} ->
        case apply_constraint(constraint, val, constraint_value) do
          true ->
            {:cont, {:ok, val}}

          false ->
            {:halt, {:error, Error.new(path, constraint, "failed #{constraint} constraint")}}
        end
    end)
  end

  # String constraints
  @spec apply_constraint(
          :choices
          | :format
          | :gt
          | :gteq
          | :lt
          | :lteq
          | :max_items
          | :max_length
          | :min_items
          | :min_length
          | :size?,
          term(),
          term()
        ) :: boolean()
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
  defp apply_constraint(:format, value, regex)
       when is_binary(value) and is_struct(regex, Regex) do
    Regex.match?(regex, value)
  end

  # Choices constraint
  defp apply_constraint(:choices, value, allowed_values) do
    value in allowed_values
  end

  # Handle unknown constraints gracefully
  defp apply_constraint(_constraint, _value, _constraint_value) do
    # Unknown constraints pass through
    true
  end

  # Array validation
  @spec validate_array_items(
          [term()],
          Elixact.Types.type_definition(),
          [term()],
          validation_path()
        ) :: validation_result()
  defp validate_array_items(items, type, constraints, path) do
    results =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, idx} ->
        item_path = path ++ [idx]

        case validate(type, item, item_path) do
          {:ok, validated} -> {:ok, validated}
          {:error, errors} -> {:error, List.wrap(errors)}
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        validated_array = Enum.map(oks, fn {:ok, val} -> val end)

        case apply_constraints(validated_array, constraints, path) do
          {:ok, final} -> {:ok, final}
          {:error, error} -> {:error, [error]}
        end

      {_, errors} ->
        {:error, Enum.flat_map(errors, fn {:error, errs} -> errs end)}
    end
  end

  @spec validate_map(
          term(),
          Elixact.Types.type_definition(),
          Elixact.Types.type_definition(),
          [term()],
          validation_path()
        ) :: validation_result()
  defp validate_map(value, key_type, value_type, constraints, path) when is_map(value) do
    results =
      Enum.map(value, fn {k, v} ->
        with {:ok, validated_key} <- validate(key_type, k, path ++ [:key]),
             {:ok, validated_value} <- validate(value_type, v, path ++ [validated_key]) do
          {:ok, {validated_key, validated_value}}
        else
          {:error, errors} -> {:error, errors}
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        validated_map = Map.new(Enum.map(oks, fn {:ok, kv} -> kv end))

        case apply_constraints(validated_map, constraints, path) do
          {:ok, final} -> {:ok, final}
          {:error, error} -> {:error, [error]}
        end

      {_, errors} ->
        {:error, Enum.flat_map(errors, fn {:error, errs} -> List.wrap(errs) end)}
    end
  end

  defp validate_map(value, _key_type, _value_type, _constraints, path) do
    {:error, [Error.new(path, :type, "expected map, got #{inspect(value)}")]}
  end

  @spec validate_union(term(), [Elixact.Types.type_definition()], validation_path()) ::
          validation_result()
  defp validate_union(value, types, path) do
    results =
      Enum.map(types, &validate(&1, value, path))

    case Enum.find(results, &match?({:ok, _}, &1)) do
      {:ok, validated} ->
        {:ok, validated}

      nil ->
        # If no type matches, return the most detailed error (the one with the longest path)
        detailed_errors =
          results
          |> Enum.flat_map(fn
            {:error, errors} when is_list(errors) -> errors
            {:error, error} -> [error]
            _ -> []
          end)

        case detailed_errors do
          [] ->
            {:error, [Error.new(path, :type, "value did not match any type in union")]}

          errors ->
            # Return the error with the most detailed path (longest path indicates deeper validation)
            best_error = Enum.max_by(errors, fn error -> length(error.path) end)

            if length(best_error.path) > length(path) do
              {:error, [best_error]}
            else
              {:error, [Error.new(path, :type, "value did not match any type in union")]}
            end
        end
    end
  end
end
