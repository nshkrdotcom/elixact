defmodule Elixact.EnhancedValidator do
  @moduledoc """
  Enhanced validation functionality that integrates all new Elixact features.

  This module provides a unified interface for validation using the new runtime
  capabilities, TypeAdapter functionality, advanced configuration, and wrapper
  support.
  """

  alias Elixact.{Runtime, TypeAdapter, Config, Wrapper, JsonSchema}
  alias Elixact.Runtime.DynamicSchema

  @type validation_input :: map() | term()
  @type validation_target :: DynamicSchema.t() | module() | TypeAdapter.type_spec()
  @type enhanced_options :: [
          config: Config.t(),
          wrapper_field: atom(),
          json_schema_opts: keyword(),
          type_adapter_opts: keyword()
        ]

  @doc """
  Universal validation function that handles all types of validation targets.

  ## Parameters
    * `target` - What to validate against (schema, type spec, etc.)
    * `input` - The data to validate
    * `opts` - Enhanced validation options

  ## Options
    * `:config` - Elixact.Config for validation behavior
    * `:wrapper_field` - Field name if using wrapper validation
    * `:json_schema_opts` - Options for JSON schema operations
    * `:type_adapter_opts` - Options for TypeAdapter operations

  ## Returns
    * `{:ok, validated_data}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      # Validate against a compiled schema
      iex> Elixact.EnhancedValidator.validate(MySchema, %{name: "John"})
      {:ok, %{name: "John"}}

      # Validate against a runtime schema
      iex> schema = Elixact.Runtime.create_schema([{:name, :string}])
      iex> Elixact.EnhancedValidator.validate(schema, %{name: "John"})
      {:ok, %{name: "John"}}

      # Validate against a type specification
      iex> Elixact.EnhancedValidator.validate({:array, :string}, ["a", "b"])
      {:ok, ["a", "b"]}

      # Validate with custom configuration
      iex> config = Elixact.Config.create(strict: true, coercion: :safe)
      iex> Elixact.EnhancedValidator.validate(:integer, "123", config: config)
      {:ok, 123}
  """
  @spec validate(validation_target(), validation_input(), enhanced_options()) ::
          {:ok, term()} | {:error, [Elixact.Error.t()]}
  def validate(target, input, opts \\ [])

  # Handle DynamicSchema validation
  def validate(%DynamicSchema{} = schema, input, opts) do
    config = Keyword.get(opts, :config, Config.create())
    validation_opts = Config.to_validation_opts(config)

    if Keyword.get(validation_opts, :coerce, false) do
      # Use field-by-field TypeAdapter validation for coercion
      validate_dynamic_schema_with_coercion(schema, input, validation_opts)
    else
      # Use normal Runtime validation
      Runtime.validate(input, schema, validation_opts)
    end
  end

  # Handle compiled schema module validation
  def validate(schema_module, input, opts) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      config = Keyword.get(opts, :config, Config.create())
      validation_opts = Config.to_validation_opts(config)

      case Elixact.Validator.validate_schema(schema_module, input, validation_opts[:path] || []) do
        {:ok, validated} -> {:ok, validated}
        {:error, errors} -> {:error, List.wrap(errors)}
      end
    else
      # Treat as type specification (atoms like :integer, :string are valid types)
      validate_type_spec(schema_module, input, opts)
    end
  end

  # Handle type specification validation
  def validate(type_spec, input, opts) do
    validate_type_spec(type_spec, input, opts)
  end

  @doc """
  Validates data and wraps it in a temporary schema if needed.

  ## Parameters
    * `field_name` - Name for the wrapper field
    * `type_spec` - Type specification for the field
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, extracted_value}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> Elixact.EnhancedValidator.validate_wrapped(:result, :integer, "123",
      ...>   config: Elixact.Config.create(coercion: :safe))
      {:ok, 123}

      iex> Elixact.EnhancedValidator.validate_wrapped(:items, {:array, :string}, ["a", "b"])
      {:ok, ["a", "b"]}
  """
  @spec validate_wrapped(atom(), TypeAdapter.type_spec(), term(), enhanced_options()) ::
          {:ok, term()} | {:error, [Elixact.Error.t()]}
  def validate_wrapped(field_name, type_spec, input, opts \\ []) do
    config = Keyword.get(opts, :config, Config.create())

    wrapper_opts =
      Config.to_validation_opts(config)
      |> Keyword.take([:required, :coerce])
      |> Keyword.merge(Keyword.take(opts, [:constraints, :required, :coerce]))

    # Note: This function delegates to Wrapper.wrap_and_validate
    # Type validation is handled during wrapper creation and validation
    case Wrapper.wrap_and_validate(field_name, type_spec, input, wrapper_opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, errors} ->
        {:error, errors}

      other ->
        {:error,
         [Elixact.Error.new([], :validation_error, "unexpected result: #{inspect(other)}")]}
    end
  end

  @doc """
  Validates multiple values efficiently against the same target.

  ## Parameters
    * `target` - What to validate against
    * `inputs` - List of data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, validated_list}` if all validations succeed
    * `{:error, errors_by_index}` if any validation fails

  ## Examples

      iex> Elixact.EnhancedValidator.validate_many(:string, ["a", "b", "c"])
      {:ok, ["a", "b", "c"]}

      iex> Elixact.EnhancedValidator.validate_many(:integer, [1, "bad", 3])
      {:error, %{1 => [%Elixact.Error{...}]}}
  """
  @spec validate_many(validation_target(), [validation_input()], enhanced_options()) ::
          {:ok, [term()]} | {:error, %{integer() => [Elixact.Error.t()]}}
  def validate_many(target, inputs, opts \\ []) when is_list(inputs) do
    # For type specifications, use TypeAdapter for efficiency
    if is_type_spec?(target) do
      config = Keyword.get(opts, :config, Config.create())
      type_adapter_opts = Config.to_validation_opts(config)

      adapter = TypeAdapter.create(target, type_adapter_opts)
      TypeAdapter.Instance.validate_many(adapter, inputs)
    else
      # For schemas, validate each individually
      results =
        inputs
        |> Enum.with_index()
        |> Enum.map(fn {input, index} ->
          case validate(target, input, opts) do
            {:ok, validated} -> {:ok, {index, validated}}
            {:error, errors} -> {:error, {index, errors}}
          end
        end)

      case Enum.split_with(results, &match?({:ok, _}, &1)) do
        {oks, []} ->
          validated_values =
            oks
            |> Enum.map(fn {:ok, {_index, value}} -> value end)

          {:ok, validated_values}

        {_, errors} ->
          error_map =
            errors
            |> Enum.map(fn {:error, {index, errs}} -> {index, errs} end)
            |> Map.new()

          {:error, error_map}
      end
    end
  end

  @doc """
  Validates data and generates a JSON schema for the validation target.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, validated_data, json_schema}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> schema = Elixact.Runtime.create_schema([{:name, :string}])
      iex> Elixact.EnhancedValidator.validate_with_schema(schema, %{name: "John"})
      {:ok, %{name: "John"}, %{"type" => "object", ...}}
  """
  @spec validate_with_schema(validation_target(), validation_input(), enhanced_options()) ::
          {:ok, term(), map()} | {:error, [Elixact.Error.t()]}
  def validate_with_schema(target, input, opts \\ []) do
    case validate(target, input, opts) do
      {:ok, validated_data} ->
        json_schema = generate_json_schema(target, opts)
        {:ok, validated_data, json_schema}

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Validates data and resolves all JSON schema references.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, validated_data, resolved_schema}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> Elixact.EnhancedValidator.validate_with_resolved_schema(MySchema, data)
      {:ok, validated_data, %{"type" => "object", ...}}
  """
  @spec validate_with_resolved_schema(validation_target(), validation_input(), enhanced_options()) ::
          {:ok, term(), map()} | {:error, [Elixact.Error.t()]}
  def validate_with_resolved_schema(target, input, opts \\ []) do
    case validate_with_schema(target, input, opts) do
      {:ok, validated_data, json_schema} ->
        resolver_opts = Keyword.get(opts, :json_schema_opts, [])
        resolved_schema = JsonSchema.Resolver.resolve_references(json_schema, resolver_opts)
        {:ok, validated_data, resolved_schema}

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Validates data for a specific LLM provider's structured output requirements.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `provider` - LLM provider (:openai, :anthropic, :generic)
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, validated_data, provider_schema}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> Elixact.EnhancedValidator.validate_for_llm(schema, data, :openai)
      {:ok, validated_data, %{"type" => "object", "additionalProperties" => false}}
  """
  @spec validate_for_llm(validation_target(), validation_input(), atom(), enhanced_options()) ::
          {:ok, term(), map()} | {:error, [Elixact.Error.t()]}
  def validate_for_llm(target, input, provider, opts \\ []) do
    case validate_with_schema(target, input, opts) do
      {:ok, validated_data, json_schema} ->
        provider_schema =
          JsonSchema.Resolver.enforce_structured_output(json_schema, provider: provider)

        {:ok, validated_data, provider_schema}

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Creates a basic validation pipeline for simple sequential validation.

  ## Parameters
    * `steps` - List of validation steps to execute in order
    * `input` - The data to validate through the pipeline
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, final_validated_data}` if all steps succeed
    * `{:error, {step_index, errors}}` if any step fails

  ## Examples

      iex> steps = [:string, fn s -> {:ok, String.upcase(s)} end, :string]
      iex> Elixact.EnhancedValidator.pipeline(steps, "hello", [])
      {:ok, "HELLO"}
  """
  @spec pipeline([term()], term(), enhanced_options()) ::
          {:ok, term()} | {:error, {integer(), [Elixact.Error.t()]}}
  def pipeline(steps, input, opts \\ []) do
    steps
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, input}, fn {step, index}, {:ok, current_value} ->
      case execute_pipeline_step(step, current_value, opts) do
        {:ok, validated} -> {:cont, {:ok, validated}}
        {:error, errors} -> {:halt, {:error, {index, errors}}}
      end
    end)
  end

  # Private helper functions

  @spec validate_dynamic_schema_with_coercion(DynamicSchema.t(), map(), keyword()) ::
          {:ok, map()} | {:error, [Elixact.Error.t()]}
  defp validate_dynamic_schema_with_coercion(%DynamicSchema{} = schema, input, validation_opts) do
    path = Keyword.get(validation_opts, :path, [])

    # Handle nil or non-map input
    if not is_map(input) do
      error = Elixact.Error.new(path, :type, "expected a map, got: #{inspect(input)}")
      {:error, [error]}
    else
      # Validate each field with coercion using TypeAdapter
      result =
        Enum.reduce_while(schema.fields, {:ok, %{}}, fn {field_name, field_meta}, {:ok, acc} ->
          field_path = path ++ [field_name]

          # Get field value from input (supporting both atom and string keys)
          field_value = Map.get(input, field_name) || Map.get(input, Atom.to_string(field_name))

          case {field_value, field_meta} do
            {nil, %Elixact.FieldMeta{default: default}} when not is_nil(default) ->
              # Use default value
              {:cont, {:ok, Map.put(acc, field_name, default)}}

            {nil, %Elixact.FieldMeta{required: false}} ->
              # Optional field without value
              {:cont, {:ok, acc}}

            {nil, %Elixact.FieldMeta{required: true}} ->
              # Required field missing
              error = Elixact.Error.new(field_path, :required, "field is required")
              {:halt, {:error, [error]}}

            {value, _} ->
              # Validate field with coercion
              case TypeAdapter.validate(field_meta.type, value, coerce: true, path: field_path) do
                {:ok, validated_value} ->
                  {:cont, {:ok, Map.put(acc, field_name, validated_value)}}

                {:error, errors} ->
                  {:halt, {:error, errors}}
              end
          end
        end)

      case result do
        {:ok, validated_fields} ->
          # Check for extra fields if strict mode is enabled
          if Keyword.get(validation_opts, :strict, false) do
            validate_strict_mode_enhanced(schema, validated_fields, input, path)
          else
            {:ok, validated_fields}
          end

        {:error, errors} ->
          {:error, errors}
      end
    end
  end

  @spec validate_strict_mode_enhanced(DynamicSchema.t(), map(), map(), [atom()]) ::
          {:ok, map()} | {:error, [Elixact.Error.t()]}
  defp validate_strict_mode_enhanced(
         %DynamicSchema{} = schema,
         validated_fields,
         original_input,
         path
       ) do
    allowed_keys = Map.keys(schema.fields) |> Enum.map(&Atom.to_string/1) |> MapSet.new()
    input_keys = Map.keys(original_input) |> Enum.map(&to_string/1) |> MapSet.new()

    case MapSet.difference(input_keys, allowed_keys) |> MapSet.to_list() do
      [] ->
        {:ok, validated_fields}

      extra_keys ->
        error =
          Elixact.Error.new(
            path,
            :additional_properties,
            "unknown fields: #{inspect(extra_keys)}"
          )

        {:error, [error]}
    end
  end

  @spec execute_pipeline_step(term(), term(), enhanced_options()) ::
          {:ok, term()} | {:error, [Elixact.Error.t()]}
  defp execute_pipeline_step(step, value, opts) do
    case step do
      # Function transformation
      fun when is_function(fun, 1) ->
        case fun.(value) do
          {:ok, transformed} -> {:ok, transformed}
          {:error, error} -> {:error, [error]}
          # Assume direct transformation
          other -> {:ok, other}
        end

      # Type validation
      type_spec ->
        validate(type_spec, value, opts)
    end
  end

  @spec validate_type_spec(TypeAdapter.type_spec(), validation_input(), enhanced_options()) ::
          {:ok, term()} | {:error, [Elixact.Error.t()]}
  defp validate_type_spec(type_spec, input, opts) do
    # Check if it's a non-existent module being treated as a type spec
    if is_atom(type_spec) do
      atom_str = Atom.to_string(type_spec)
      normalized = Elixact.Types.normalize_type(type_spec)

      # If normalize_type returns the atom unchanged (not a known type or schema),
      # and it looks like a module name, it's likely invalid
      if is_atom(normalized) and normalized == type_spec and String.match?(atom_str, ~r/^[A-Z]/) do
        # Double-check: if it's an atom that normalize_type didn't transform,
        # and it starts with a capital letter, check if it's a valid module
        unless Code.ensure_loaded?(type_spec) and function_exported?(type_spec, :__schema__, 1) do
          raise ArgumentError, "Module #{inspect(type_spec)} does not exist"
        end
      end
    end

    config = Keyword.get(opts, :config, Config.create())

    type_adapter_opts =
      Config.to_validation_opts(config)
      |> Keyword.merge(Keyword.get(opts, :type_adapter_opts, []))

    TypeAdapter.validate(type_spec, input, type_adapter_opts)
  end

  @spec generate_json_schema(validation_target(), enhanced_options()) :: map()
  defp generate_json_schema(%DynamicSchema{} = schema, opts) do
    config = Keyword.get(opts, :config, Config.create())
    json_schema_opts = Keyword.get(opts, :json_schema_opts, [])

    # Extract config settings that should influence JSON schema generation
    schema_opts =
      json_schema_opts
      |> Keyword.put_new(:strict, config.strict)
      |> Keyword.put_new(
        :additional_properties,
        if config.strict do
          false
        else
          json_schema_opts[:additional_properties]
        end
      )

    Runtime.to_json_schema(schema, schema_opts)
  end

  defp generate_json_schema(schema_module, opts) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      JsonSchema.from_schema(schema_module)
    else
      # Type specification
      json_schema_opts = Keyword.get(opts, :json_schema_opts, [])
      TypeAdapter.json_schema(schema_module, json_schema_opts)
    end
  end

  defp generate_json_schema(type_spec, opts) do
    json_schema_opts = Keyword.get(opts, :json_schema_opts, [])
    TypeAdapter.json_schema(type_spec, json_schema_opts)
  end

  @spec is_type_spec?(term()) :: boolean()
  defp is_type_spec?(%DynamicSchema{}), do: false

  defp is_type_spec?(atom) when is_atom(atom) do
    not (Code.ensure_loaded?(atom) and function_exported?(atom, :__schema__, 1))
  end

  defp is_type_spec?(_), do: true

  @doc """
  Creates a comprehensive validation report for debugging purposes.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * Map with detailed validation information

  ## Examples

      iex> report = Elixact.EnhancedValidator.validation_report(schema, data)
      %{
        validation_result: {:ok, validated_data},
        json_schema: %{...},
        target_info: %{...},
        input_analysis: %{...},
        performance_metrics: %{...}
      }
  """
  @spec validation_report(validation_target(), validation_input(), enhanced_options()) :: map()
  def validation_report(target, input, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    validation_result = validate(target, input, opts)

    end_time = System.monotonic_time(:microsecond)
    duration_us = end_time - start_time

    %{
      validation_result: validation_result,
      json_schema: generate_json_schema(target, opts),
      target_info: analyze_target(target),
      input_analysis: analyze_input(input),
      performance_metrics: %{
        duration_microseconds: duration_us,
        duration_milliseconds: duration_us / 1000
      },
      configuration: Keyword.get(opts, :config, Config.create()) |> Config.summary(),
      timestamp: DateTime.utc_now()
    }
  end

  defp analyze_target(%DynamicSchema{} = schema) do
    %{
      type: :dynamic_schema,
      name: schema.name,
      field_count: map_size(schema.fields),
      summary: Runtime.DynamicSchema.summary(schema)
    }
  end

  defp analyze_target(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      %{
        type: :compiled_schema,
        module: schema_module,
        fields: schema_module.__schema__(:fields) |> length()
      }
    else
      %{
        type: :type_specification,
        spec: schema_module
      }
    end
  end

  defp analyze_target(type_spec) do
    %{
      type: :type_specification,
      spec: type_spec,
      normalized: Elixact.Types.normalize_type(type_spec)
    }
  end

  defp analyze_input(input) when is_map(input) do
    %{
      type: :map,
      key_count: map_size(input),
      keys: Map.keys(input),
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_list(input) do
    %{
      type: :list,
      length: length(input),
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_tuple(input) do
    %{
      type: :tuple,
      size: tuple_size(input),
      element_types: input |> Tuple.to_list() |> Enum.map(&get_type/1),
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_binary(input) do
    %{
      type: :string,
      length: String.length(input),
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_integer(input) do
    %{
      type: :integer,
      value: input,
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_float(input) do
    %{
      type: :float,
      value: input,
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_boolean(input) do
    %{
      type: :boolean,
      value: input,
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_atom(input) do
    %{
      type: :atom,
      value: input,
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) do
    %{
      type: :unknown,
      erlang_type: input |> elem(0) |> to_string(),
      size_bytes: :erlang.external_size(input)
    }
  rescue
    # If elem/2 fails, it's not a tuple
    _ ->
      %{
        type: :unknown,
        size_bytes: :erlang.external_size(input)
      }
  end

  defp get_type(value) when is_binary(value), do: :string
  defp get_type(value) when is_integer(value), do: :integer
  defp get_type(value) when is_float(value), do: :float
  defp get_type(value) when is_boolean(value), do: :boolean
  defp get_type(value) when is_atom(value), do: :atom
  defp get_type(value) when is_list(value), do: :list
  defp get_type(value) when is_map(value), do: :map
  defp get_type(value) when is_tuple(value), do: :tuple
  defp get_type(_), do: :unknown
end
