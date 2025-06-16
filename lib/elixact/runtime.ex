defmodule Elixact.Runtime do
  @moduledoc """
  Runtime schema generation and validation capabilities.

  This module enables dynamic schema creation from field definitions at runtime,
  supporting the DSPy pattern of `pydantic.create_model("DSPyProgramOutputs", **fields)`.
  """

  alias Elixact.Runtime.DynamicSchema
  alias Elixact.{FieldMeta, Validator}
  alias Elixact.JsonSchema.{ReferenceStore, TypeMapper}

  @type field_definition :: {atom(), type_spec()} | {atom(), type_spec(), keyword()}
  @type type_spec :: Elixact.Types.type_definition() | atom() | module()
  @type schema_option :: {:title, String.t()} | {:description, String.t()} | {:strict, boolean()}

  @doc """
  Creates a schema at runtime from field definitions.

  ## Parameters
    * `field_definitions` - List of field definitions in the format:
      - `{field_name, type}` 
      - `{field_name, type, options}`
    * `opts` - Schema configuration options

  ## Options
    * `:title` - Schema title
    * `:description` - Schema description  
    * `:strict` - Enable strict validation (default: false)
    * `:name` - Schema name for references

  ## Examples

      iex> fields = [
      ...>   {:name, :string, [required: true, min_length: 2]},
      ...>   {:age, :integer, [optional: true, gt: 0]},
      ...>   {:email, :string, [required: true, format: ~r/@/]}
      ...> ]
      iex> schema = Elixact.Runtime.create_schema(fields, title: "User Schema")
      %Elixact.Runtime.DynamicSchema{...}
  """
  @spec create_schema([field_definition()], [schema_option()]) :: DynamicSchema.t()
  def create_schema(field_definitions, opts \\ []) do
    name = Keyword.get(opts, :name, generate_schema_name())

    config = %{
      title: Keyword.get(opts, :title),
      description: Keyword.get(opts, :description),
      strict: Keyword.get(opts, :strict, false)
    }

    fields =
      field_definitions
      |> Enum.map(&normalize_field_definition/1)
      |> Map.new(fn {name, meta} -> {name, meta} end)

    %DynamicSchema{
      name: name,
      fields: fields,
      config: config,
      metadata: %{
        created_at: DateTime.utc_now(),
        field_count: map_size(fields)
      }
    }
  end

  @doc """
  Validates data against a runtime-created schema.

  ## Parameters
    * `data` - The data to validate (map)
    * `dynamic_schema` - A DynamicSchema struct
    * `opts` - Validation options

  ## Returns
    * `{:ok, validated_data}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> data = %{name: "John", age: 30}
      iex> Elixact.Runtime.validate(data, schema)
      {:ok, %{name: "John", age: 30}}
  """
  @spec validate(map(), DynamicSchema.t(), keyword()) ::
          {:ok, map()} | {:error, [Elixact.Error.t()]}
  def validate(data, %DynamicSchema{} = schema, opts \\ []) do
    path = Keyword.get(opts, :path, [])
    # Runtime opts override schema config
    runtime_strict = Keyword.get(opts, :strict, schema.config[:strict])
    config = Map.put(schema.config, :strict, runtime_strict)

    with :ok <- validate_required_fields(schema.fields, data, path),
         {:ok, validated} <- validate_fields(schema.fields, data, path),
         :ok <- validate_strict_mode(config, validated, data, path) do
      {:ok, validated}
    else
      {:error, errors} when is_list(errors) ->
        {:error, errors}

      {:error, error} when is_struct(error, Elixact.Error) ->
        {:error, [error]}

      {:error, other} ->
        {:error, [other]}
    end
  end

  @doc """
  Generates JSON Schema from a runtime schema.

  ## Parameters
    * `dynamic_schema` - A DynamicSchema struct
    * `opts` - JSON Schema generation options

  ## Returns
    * JSON Schema map

  ## Examples

      iex> json_schema = Elixact.Runtime.to_json_schema(schema)
      %{"type" => "object", "properties" => %{...}}
  """
  @spec to_json_schema(DynamicSchema.t(), keyword()) :: map()
  def to_json_schema(%DynamicSchema{} = schema, opts \\ []) do
    {:ok, store} = ReferenceStore.start_link()

    try do
      base_schema =
        %{
          "type" => "object",
          "title" => schema.config[:title],
          "description" => schema.config[:description],
          "properties" => %{},
          "required" => []
        }
        |> maybe_add_additional_properties(
          schema.config[:strict] ||
            Keyword.get(opts, :additional_properties) == false ||
            Keyword.get(opts, :strict, false)
        )
        |> Map.reject(fn {_, v} -> is_nil(v) end)

      schema_with_fields =
        Enum.reduce(schema.fields, base_schema, fn {name, field_meta}, acc ->
          # Add to properties
          properties = Map.get(acc, "properties", %{})

          field_schema =
            TypeMapper.to_json_schema(field_meta.type, store)
            |> Map.merge(convert_field_metadata(field_meta))
            |> Map.reject(fn {_, v} -> is_nil(v) end)

          updated_properties = Map.put(properties, Atom.to_string(name), field_schema)
          acc = Map.put(acc, "properties", updated_properties)

          # Add to required if needed
          if field_meta.required do
            required = Map.get(acc, "required", [])
            Map.put(acc, "required", [Atom.to_string(name) | required])
          else
            acc
          end
        end)

      # Add definitions if any references were created
      definitions = ReferenceStore.get_definitions(store)

      if map_size(definitions) > 0 do
        Map.put(schema_with_fields, "definitions", definitions)
      else
        schema_with_fields
      end
    after
      ReferenceStore.stop(store)
    end
  end

  # Private helper functions

  @spec normalize_field_definition(field_definition()) :: {atom(), FieldMeta.t()}
  defp normalize_field_definition({name, type}) do
    normalize_field_definition({name, type, []})
  end

  defp normalize_field_definition({name, type, opts}) when is_atom(name) do
    field_meta = %FieldMeta{
      name: name,
      type: normalize_type_definition(type, opts),
      required: determine_required(opts),
      description: Keyword.get(opts, :description),
      example: Keyword.get(opts, :example),
      examples: Keyword.get(opts, :examples),
      default: Keyword.get(opts, :default),
      constraints: extract_constraints(opts)
    }

    # If default is provided, make field optional
    field_meta =
      if field_meta.default do
        %{field_meta | required: false}
      else
        field_meta
      end

    {name, field_meta}
  end

  @spec normalize_type_definition(type_spec(), keyword()) :: Elixact.Types.type_definition()
  defp normalize_type_definition(type, opts) when is_atom(type) do
    constraints = extract_constraints(opts)

    cond do
      type in [:string, :integer, :float, :boolean, :any, :atom, :map] ->
        {:type, type, constraints}

      Code.ensure_loaded?(type) and function_exported?(type, :__schema__, 1) ->
        {:ref, type}

      true ->
        {:type, type, constraints}
    end
  end

  defp normalize_type_definition({:array, inner_type}, opts) do
    constraints = extract_constraints(opts)
    {:array, normalize_type_definition(inner_type, []), constraints}
  end

  defp normalize_type_definition({:map, {key_type, value_type}}, opts) do
    constraints = extract_constraints(opts)
    normalized_key = normalize_type_definition(key_type, [])
    normalized_value = normalize_type_definition(value_type, [])
    {:map, {normalized_key, normalized_value}, constraints}
  end

  defp normalize_type_definition({:union, types}, opts) do
    constraints = extract_constraints(opts)
    normalized_types = Enum.map(types, &normalize_type_definition(&1, []))
    {:union, normalized_types, constraints}
  end

  defp normalize_type_definition(type, opts) do
    constraints = extract_constraints(opts)
    {Elixact.Types.normalize_type(type), constraints}
  end

  @spec determine_required(keyword()) :: boolean()
  defp determine_required(opts) do
    cond do
      Keyword.has_key?(opts, :required) -> Keyword.get(opts, :required)
      Keyword.get(opts, :optional, false) -> false
      true -> true
    end
  end

  @spec extract_constraints(keyword()) :: [term()]
  defp extract_constraints(opts) do
    constraint_keys =
      MapSet.new([
        :min_length,
        :max_length,
        :min_items,
        :max_items,
        :gt,
        :lt,
        :gteq,
        :lteq,
        :format,
        :choices
      ])

    Enum.filter(opts, fn {key, _value} ->
      MapSet.member?(constraint_keys, key)
    end)
  end

  @spec validate_required_fields(map(), map(), [atom()]) :: :ok | {:error, Elixact.Error.t()}
  defp validate_required_fields(fields, data, path) do
    required_fields =
      fields
      |> Enum.filter(fn {_, meta} -> meta.required end)
      |> Enum.map(fn {name, _} -> name end)

    case Enum.find(required_fields, fn field ->
           not (Map.has_key?(data, field) or Map.has_key?(data, Atom.to_string(field)))
         end) do
      nil -> :ok
      field -> {:error, Elixact.Error.new([field | path], :required, "field is required")}
    end
  end

  @spec validate_fields(map(), map(), [atom()]) ::
          {:ok, map()} | {:error, Elixact.Error.t() | [Elixact.Error.t()]}
  defp validate_fields(fields, data, path) do
    {validated, errors} =
      Enum.reduce(fields, {%{}, []}, fn {name, meta}, {acc, errors_acc} ->
        field_path = path ++ [name]
        value = Map.get(data, name) || Map.get(data, Atom.to_string(name))

        case {value, meta} do
          {nil, %{default: default}} ->
            {Map.put(acc, name, default), errors_acc}

          {nil, %{required: false}} ->
            {acc, errors_acc}

          {nil, _} ->
            error = Elixact.Error.new(field_path, :required, "field is required")
            {acc, [error | errors_acc]}

          {value, _} ->
            case Validator.validate(meta.type, value, field_path) do
              {:ok, validated_value} ->
                {Map.put(acc, name, validated_value), errors_acc}

              {:error, field_errors} when is_list(field_errors) ->
                {acc, field_errors ++ errors_acc}

              {:error, field_error} ->
                {acc, [field_error | errors_acc]}
            end
        end
      end)

    case errors do
      [] -> {:ok, validated}
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  @spec validate_strict_mode(map(), map(), map(), [atom()]) :: :ok | {:error, Elixact.Error.t()}
  defp validate_strict_mode(%{strict: true}, validated, original, path) do
    validated_keys = Map.keys(validated) |> Enum.map(&Atom.to_string/1) |> MapSet.new()
    original_keys = Map.keys(original) |> Enum.map(&to_string/1) |> MapSet.new()

    case MapSet.difference(original_keys, validated_keys) |> MapSet.to_list() do
      [] ->
        :ok

      extra ->
        {:error,
         Elixact.Error.new(path, :additional_properties, "unknown fields: #{inspect(extra)}")}
    end
  end

  defp validate_strict_mode(_, _, _, _), do: :ok

  @spec maybe_add_additional_properties(map(), boolean() | nil) :: map()
  defp maybe_add_additional_properties(schema, true) do
    Map.put(schema, "additionalProperties", false)
  end

  defp maybe_add_additional_properties(schema, _), do: schema

  @spec convert_field_metadata(FieldMeta.t()) :: map()
  defp convert_field_metadata(field_meta) do
    base = %{
      "description" => field_meta.description,
      "default" => field_meta.default
    }

    # Handle examples
    base =
      cond do
        examples = field_meta.examples ->
          Map.put(base, "examples", examples)

        example = field_meta.example ->
          Map.put(base, "examples", [example])

        true ->
          base
      end

    Map.reject(base, fn {_, v} -> is_nil(v) end)
  end

  @spec generate_schema_name() :: String.t()
  defp generate_schema_name do
    "DynamicSchema_#{System.unique_integer([:positive])}"
  end
end
