defmodule Elixact.Config do
  @moduledoc """
  Advanced configuration with runtime modification support.

  This module provides functionality for creating and manipulating validation
  configuration at runtime, supporting the DSPy pattern of dynamic config
  modification like `ConfigDict(extra="forbid", frozen=True)`.
  """

  @enforce_keys []
  defstruct [
    # Enforce strict validation (no extra fields)
    strict: false,
    # How to handle extra fields (:allow, :forbid, :ignore)
    extra: :allow,
    # Type coercion strategy (:none, :safe, :aggressive)
    coercion: :safe,
    # Whether the config is immutable
    frozen: false,
    # Validate field assignments
    validate_assignment: false,
    # Use enum values instead of names
    use_enum_values: false,
    # Allow both field names and aliases
    allow_population_by_field_name: true,
    # Case sensitivity for field names
    case_sensitive: true,
    # Error format (:detailed, :simple, :minimal)
    error_format: :detailed,
    # Maximum length for anyOf unions
    max_anyof_union_len: 5,
    # Function to generate titles
    title_generator: nil,
    # Function to generate descriptions
    description_generator: nil
  ]

  @type extra_strategy :: :allow | :forbid | :ignore
  @type coercion_strategy :: :none | :safe | :aggressive
  @type error_format :: :detailed | :simple | :minimal

  @type t :: %__MODULE__{
          strict: boolean(),
          extra: extra_strategy(),
          coercion: coercion_strategy(),
          frozen: boolean(),
          validate_assignment: boolean(),
          use_enum_values: boolean(),
          allow_population_by_field_name: boolean(),
          case_sensitive: boolean(),
          error_format: error_format(),
          max_anyof_union_len: non_neg_integer(),
          title_generator: (atom() -> String.t()) | nil,
          description_generator: (atom() -> String.t()) | nil
        }

  @doc """
  Creates a new configuration with the specified options.

  ## Parameters
    * `opts` - Configuration options as keyword list or map

  ## Options
    * `:strict` - Enforce strict validation (default: false)
    * `:extra` - How to handle extra fields (default: :allow)
    * `:coercion` - Type coercion strategy (default: :safe)
    * `:frozen` - Whether the config is immutable (default: false)
    * `:validate_assignment` - Validate field assignments (default: false)
    * `:error_format` - Error format style (default: :detailed)

  ## Returns
    * New Config struct

  ## Examples

      iex> config = Elixact.Config.create(strict: true, extra: :forbid)
      %Elixact.Config{strict: true, extra: :forbid, ...}

      iex> config = Elixact.Config.create(%{coercion: :aggressive, frozen: true})
      %Elixact.Config{coercion: :aggressive, frozen: true, ...}
  """
  @spec create(keyword() | map()) :: t()
  def create(opts \\ []) do
    opts_map =
      case opts do
        map when is_map(map) -> map
        keyword when is_list(keyword) -> Map.new(keyword)
      end

    # Validate that all keys are valid struct fields
    valid_keys = __MODULE__.__struct__() |> Map.keys() |> MapSet.new()
    provided_keys = opts_map |> Map.keys() |> MapSet.new()

    case MapSet.difference(provided_keys, valid_keys) |> MapSet.to_list() do
      [] ->
        # Validate option values
        validate_option_values!(opts_map)
        struct!(__MODULE__, opts_map)

      invalid_keys ->
        raise ArgumentError, "Invalid configuration options: #{inspect(invalid_keys)}"
    end
  end

  @doc """
  Merges configuration options with an existing config.

  ## Parameters
    * `base_config` - The base configuration
    * `overrides` - Configuration options to merge/override

  ## Returns
    * New Config struct with merged options
    * Raises if base config is frozen and overrides are provided

  ## Examples

      iex> base = Elixact.Config.create(strict: true)
      iex> merged = Elixact.Config.merge(base, %{extra: :forbid, coercion: :none})
      %Elixact.Config{strict: true, extra: :forbid, coercion: :none, ...}

      iex> frozen = Elixact.Config.create(frozen: true)
      iex> Elixact.Config.merge(frozen, %{strict: true})
      ** (RuntimeError) Cannot modify frozen configuration
  """
  @spec merge(t(), map() | keyword()) :: t()
  def merge(%__MODULE__{frozen: true} = config, overrides) do
    overrides_map =
      case overrides do
        map when is_map(map) -> map
        keyword when is_list(keyword) -> Map.new(keyword)
      end

    # Check if overrides is empty
    is_empty = map_size(overrides_map) == 0

    if is_empty do
      # Return the frozen config unchanged for empty overrides
      config
    else
      # Frozen configs cannot be modified - this is the expected behavior
      raise RuntimeError, "Cannot modify frozen configuration"
    end
  end

  def merge(%__MODULE__{} = base_config, overrides) do
    overrides_map =
      case overrides do
        map when is_map(map) -> map
        keyword when is_list(keyword) -> Map.new(keyword)
      end

    struct!(base_config, overrides_map)
  end

  @doc """
  Creates a preset configuration for common validation scenarios.

  ## Parameters
    * `preset` - The preset name

  ## Available Presets
    * `:strict` - Strict validation with no extra fields
    * `:lenient` - Lenient validation allowing extra fields
    * `:api` - Configuration suitable for API validation
    * `:json_schema` - Configuration optimized for JSON Schema generation
    * `:development` - Development-friendly configuration
    * `:production` - Production-ready configuration

  ## Returns
    * Pre-configured Config struct

  ## Examples

      iex> Elixact.Config.preset(:strict)
      %Elixact.Config{strict: true, extra: :forbid, coercion: :none, ...}

      iex> Elixact.Config.preset(:lenient)
      %Elixact.Config{strict: false, extra: :allow, coercion: :safe, ...}
  """
  @spec preset(:strict | :lenient | :api | :json_schema | :development | :production) :: t()
  def preset(:strict) do
    create(%{
      strict: true,
      extra: :forbid,
      coercion: :none,
      validate_assignment: true,
      case_sensitive: true,
      error_format: :detailed
    })
  end

  def preset(:lenient) do
    create(%{
      strict: false,
      extra: :allow,
      coercion: :safe,
      validate_assignment: false,
      case_sensitive: false,
      error_format: :simple
    })
  end

  def preset(:api) do
    create(%{
      strict: true,
      extra: :forbid,
      coercion: :safe,
      validate_assignment: true,
      case_sensitive: true,
      error_format: :detailed,
      frozen: true
    })
  end

  def preset(:json_schema) do
    create(%{
      strict: false,
      extra: :allow,
      coercion: :none,
      use_enum_values: true,
      error_format: :minimal,
      max_anyof_union_len: 3
    })
  end

  def preset(:development) do
    create(%{
      strict: false,
      extra: :allow,
      coercion: :aggressive,
      validate_assignment: false,
      case_sensitive: false,
      error_format: :detailed
    })
  end

  def preset(:production) do
    create(%{
      strict: true,
      extra: :forbid,
      coercion: :safe,
      validate_assignment: true,
      case_sensitive: true,
      error_format: :simple,
      frozen: true
    })
  end

  def preset(unknown) do
    raise ArgumentError, "Unknown preset: #{inspect(unknown)}"
  end

  @doc """
  Validates configuration options for consistency.

  ## Parameters
    * `config` - The configuration to validate

  ## Returns
    * `:ok` if configuration is valid
    * `{:error, reasons}` if configuration has issues

  ## Examples

      iex> config = Elixact.Config.create(strict: true, extra: :allow)
      iex> Elixact.Config.validate_config(config)
      {:error, ["strict mode conflicts with extra: :allow"]}

      iex> config = Elixact.Config.create(strict: true, extra: :forbid)
      iex> Elixact.Config.validate_config(config)
      :ok
  """
  @spec validate_config(t()) :: :ok | {:error, [String.t()]}
  def validate_config(%__MODULE__{} = config) do
    errors = []

    errors =
      if config.strict and config.extra == :allow do
        ["strict mode conflicts with extra: :allow" | errors]
      else
        errors
      end

    errors =
      if config.coercion == :aggressive and config.validate_assignment do
        ["aggressive coercion conflicts with validate_assignment" | errors]
      else
        errors
      end

    errors =
      if config.max_anyof_union_len < 1 do
        ["max_anyof_union_len must be at least 1" | errors]
      else
        errors
      end

    case errors do
      [] -> :ok
      reasons -> {:error, Enum.reverse(reasons)}
    end
  end

  @doc """
  Converts configuration to options suitable for validation functions.

  ## Parameters
    * `config` - The configuration to convert

  ## Returns
    * Keyword list of validation options

  ## Examples

      iex> config = Elixact.Config.create(strict: true, coercion: :safe)
      iex> Elixact.Config.to_validation_opts(config)
      [strict: true, coerce: true, error_format: :detailed, ...]
  """
  @spec to_validation_opts(t()) :: keyword()
  def to_validation_opts(%__MODULE__{} = config) do
    [
      strict: config.strict,
      coerce: config.coercion != :none,
      coercion_strategy: config.coercion,
      extra: config.extra,
      validate_assignment: config.validate_assignment,
      case_sensitive: config.case_sensitive,
      error_format: config.error_format,
      allow_population_by_field_name: config.allow_population_by_field_name
    ]
  end

  @doc """
  Converts configuration to options suitable for JSON Schema generation.

  ## Parameters
    * `config` - The configuration to convert

  ## Returns
    * Keyword list of JSON Schema options

  ## Examples

      iex> config = Elixact.Config.create(strict: true, use_enum_values: true)
      iex> Elixact.Config.to_json_schema_opts(config)
      [strict: true, use_enum_values: true, max_anyof_union_len: 5, ...]
  """
  @spec to_json_schema_opts(t()) :: keyword()
  def to_json_schema_opts(%__MODULE__{} = config) do
    [
      strict: config.strict,
      use_enum_values: config.use_enum_values,
      max_anyof_union_len: config.max_anyof_union_len,
      title_generator: config.title_generator,
      description_generator: config.description_generator
    ]
  end

  @doc """
  Checks if extra fields should be allowed based on configuration.

  ## Parameters
    * `config` - The configuration to check

  ## Returns
    * `true` if extra fields are allowed, `false` otherwise

  ## Examples

      iex> config = Elixact.Config.create(extra: :allow)
      iex> Elixact.Config.allow_extra_fields?(config)
      true

      iex> config = Elixact.Config.create(extra: :forbid)
      iex> Elixact.Config.allow_extra_fields?(config)
      false
  """
  @spec allow_extra_fields?(t()) :: boolean()
  def allow_extra_fields?(%__MODULE__{extra: :allow}), do: true
  def allow_extra_fields?(%__MODULE__{extra: :forbid}), do: false
  def allow_extra_fields?(%__MODULE__{extra: :ignore}), do: true

  @doc """
  Checks if type coercion should be performed based on configuration.

  ## Parameters
    * `config` - The configuration to check

  ## Returns
    * `true` if coercion should be performed, `false` otherwise

  ## Examples

      iex> config = Elixact.Config.create(coercion: :safe)
      iex> Elixact.Config.should_coerce?(config)
      true

      iex> config = Elixact.Config.create(coercion: :none)
      iex> Elixact.Config.should_coerce?(config)
      false
  """
  @spec should_coerce?(t()) :: boolean()
  def should_coerce?(%__MODULE__{coercion: :none}), do: false
  def should_coerce?(%__MODULE__{coercion: _}), do: true

  @doc """
  Gets the coercion aggressiveness level.

  ## Parameters
    * `config` - The configuration to check

  ## Returns
    * Coercion strategy atom

  ## Examples

      iex> config = Elixact.Config.create(coercion: :aggressive)
      iex> Elixact.Config.coercion_level(config)
      :aggressive
  """
  @spec coercion_level(t()) :: coercion_strategy()
  def coercion_level(%__MODULE__{coercion: level}), do: level

  @doc """
  Returns a summary of the configuration settings.

  ## Parameters
    * `config` - The configuration to summarize

  ## Returns
    * Map with configuration summary

  ## Examples

      iex> config = Elixact.Config.create(strict: true, extra: :forbid)
      iex> Elixact.Config.summary(config)
      %{
        validation_mode: "strict",
        extra_fields: "forbidden",
        coercion: "safe",
        frozen: false,
        features: ["validate_assignment", ...]
      }
  """
  @spec summary(t()) :: %{
          validation_mode: String.t(),
          extra_fields: String.t(),
          coercion: String.t(),
          frozen: boolean(),
          error_format: String.t(),
          features: [String.t()]
        }
  def summary(%__MODULE__{} = config) do
    %{
      validation_mode: if(config.strict, do: "strict", else: "lenient"),
      extra_fields:
        case config.extra do
          :allow -> "allowed"
          :forbid -> "forbidden"
          :ignore -> "ignored"
        end,
      coercion: Atom.to_string(config.coercion),
      frozen: config.frozen,
      error_format: Atom.to_string(config.error_format),
      features: enabled_features(config)
    }
  end

  @doc """
  Creates a builder for fluent configuration creation.

  ## Returns
    * ConfigBuilder struct for chaining configuration calls

  ## Examples

      iex> config = Elixact.Config.builder()
      ...> |> Elixact.Config.Builder.strict(true)
      ...> |> Elixact.Config.Builder.forbid_extra()
      ...> |> Elixact.Config.Builder.safe_coercion()
      ...> |> Elixact.Config.Builder.build()
      %Elixact.Config{strict: true, extra: :forbid, coercion: :safe, ...}
  """
  @spec builder() :: Elixact.Config.Builder.t()
  def builder do
    Elixact.Config.Builder.new()
  end

  # Private helper functions

  @spec validate_option_values!(map()) :: :ok
  defp validate_option_values!(opts_map) do
    Enum.each(opts_map, fn {key, value} ->
      case key do
        :strict ->
          unless is_boolean(value), do: raise(ArgumentError, "strict must be a boolean")

        :extra ->
          unless value in [:allow, :forbid, :ignore],
            do: raise(ArgumentError, "extra must be :allow, :forbid, or :ignore")

        :coercion ->
          unless value in [:none, :safe, :aggressive],
            do: raise(ArgumentError, "coercion must be :none, :safe, or :aggressive")

        :frozen ->
          unless is_boolean(value), do: raise(ArgumentError, "frozen must be a boolean")

        :validate_assignment ->
          unless is_boolean(value),
            do: raise(ArgumentError, "validate_assignment must be a boolean")

        :use_enum_values ->
          unless is_boolean(value), do: raise(ArgumentError, "use_enum_values must be a boolean")

        :allow_population_by_field_name ->
          unless is_boolean(value),
            do: raise(ArgumentError, "allow_population_by_field_name must be a boolean")

        :case_sensitive ->
          unless is_boolean(value), do: raise(ArgumentError, "case_sensitive must be a boolean")

        :error_format ->
          unless value in [:detailed, :simple, :minimal],
            do: raise(ArgumentError, "error_format must be :detailed, :simple, or :minimal")

        :max_anyof_union_len ->
          unless is_integer(value),
            do: raise(ArgumentError, "max_anyof_union_len must be an integer")

        :title_generator ->
          unless is_nil(value) or is_function(value, 1),
            do: raise(ArgumentError, "title_generator must be a function or nil")

        :description_generator ->
          unless is_nil(value) or is_function(value, 1),
            do: raise(ArgumentError, "description_generator must be a function or nil")

        _ ->
          :ok
      end
    end)
  end

  @spec enabled_features(t()) :: [String.t()]
  defp enabled_features(config) do
    features = []

    features =
      if config.validate_assignment, do: ["validate_assignment" | features], else: features

    features = if config.use_enum_values, do: ["use_enum_values" | features], else: features

    features =
      if config.allow_population_by_field_name,
        do: ["field_name_population" | features],
        else: features

    features = if config.case_sensitive, do: ["case_sensitive" | features], else: features
    features = if config.title_generator, do: ["title_generator" | features], else: features

    features =
      if config.description_generator, do: ["description_generator" | features], else: features

    Enum.reverse(features)
  end
end
