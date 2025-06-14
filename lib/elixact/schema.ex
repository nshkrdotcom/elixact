defmodule Elixact.Schema do
  @moduledoc """
  Schema DSL for defining data schemas with validation rules and metadata.

  This module provides macros and functions for defining structured data schemas
  with rich validation capabilities, type safety, and comprehensive error reporting.
  """

  alias Elixact.Types

  @type schema_config :: %{
          optional(:title) => String.t(),
          optional(:description) => String.t(),
          optional(:strict) => boolean()
        }

  @doc """
  Defines a new schema with optional description.

  ## Parameters
    * `description` - Optional string describing the schema's purpose
    * `do` - Block containing field definitions and configuration

  ## Examples

      schema "User registration data" do
        field :name, :string do
          required()
          min_length(2)
        end

        field :age, :integer do
          optional()
          gt(0)
        end
      end

      schema do
        field :email, :string
        field :active, :boolean, default: true
      end
  """
  @spec schema(String.t() | nil, keyword()) :: Macro.t()
  defmacro schema(description \\ nil, do: block) do
    quote do
      @schema_description unquote(description)

      unquote(block)

      # Generate validation functions
      @doc """
      Validates data against this schema.

      ## Parameters
        * `data` - The data to validate (map)

      ## Returns
        * `{:ok, validated_data}` on success
        * `{:error, errors}` on validation failure
      """
      @spec validate(map()) :: {:ok, map()} | {:error, [Elixact.Error.t()]}
      def validate(data) do
        Elixact.Validator.validate_schema(__MODULE__, data)
      end

      @doc """
      Validates data against this schema, raising an exception on failure.

      ## Parameters
        * `data` - The data to validate (map)

      ## Returns
        * Validated data on success
        * Raises `Elixact.ValidationError` on failure
      """
      @spec validate!(map()) :: map()
      def validate!(data) do
        case validate(data) do
          {:ok, validated} -> validated
          {:error, errors} -> raise Elixact.ValidationError, errors: errors
        end
      end
    end
  end

  @doc """
  Adds a minimum length constraint to a string field.

  ## Parameters
    * `value` - The minimum length required (must be a non-negative integer)

  ## Examples

      field :username, :string do
        min_length(3)
      end

      field :password, :string do
        min_length(8)
        max_length(100)
      end
  """
  @spec min_length(non_neg_integer()) :: Macro.t()
  defmacro min_length(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:min_length, unquote(value)} | current_constraints
        ])
    end
  end

  @doc """
  Adds a maximum length constraint to a string field.

  ## Parameters
    * `value` - The maximum length allowed (must be a non-negative integer)

  ## Examples

      field :username, :string do
        max_length(20)
      end

      field :description, :string do
        max_length(500)
      end
  """
  @spec max_length(non_neg_integer()) :: Macro.t()
  defmacro max_length(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:max_length, unquote(value)} | current_constraints
        ])
    end
  end

  @doc """
  Adds a minimum items constraint to an array field.

  ## Parameters
    * `value` - The minimum number of items required (must be a non-negative integer)

  ## Examples

      field :tags, {:array, :string} do
        min_items(1)
      end

      field :categories, {:array, :string} do
        min_items(2)
        max_items(5)
      end
  """
  @spec min_items(non_neg_integer()) :: Macro.t()
  defmacro min_items(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:min_items, unquote(value)} | current_constraints
        ])
    end
  end

  @doc """
  Adds a maximum items constraint to an array field.

  ## Parameters
    * `value` - The maximum number of items allowed (must be a non-negative integer)

  ## Examples

      field :tags, {:array, :string} do
        max_items(10)
      end

      field :favorites, {:array, :integer} do
        min_items(1)
        max_items(3)
      end
  """
  @spec max_items(non_neg_integer()) :: Macro.t()
  defmacro max_items(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:max_items, unquote(value)} | current_constraints
        ])
    end
  end

  @doc """
  Adds a greater than constraint to a numeric field.

  ## Parameters
    * `value` - The minimum value (exclusive)

  ## Examples

      field :age, :integer do
        gt(0)
      end

      field :score, :float do
        gt(0.0)
        lt(100.0)
      end
  """
  @spec gt(number()) :: Macro.t()
  defmacro gt(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:gt, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds a less than constraint to a numeric field.

  ## Parameters
    * `value` - The maximum value (exclusive)

  ## Examples

      field :age, :integer do
        lt(100)
      end

      field :temperature, :float do
        gt(-50.0)
        lt(100.0)
      end
  """
  @spec lt(number()) :: Macro.t()
  defmacro lt(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:lt, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds a greater than or equal to constraint to a numeric field.

  ## Parameters
    * `value` - The minimum value (inclusive)

  ## Examples

      field :age, :integer do
        gteq(18)
      end

      field :rating, :float do
        gteq(0.0)
        lteq(5.0)
      end
  """
  @spec gteq(number()) :: Macro.t()
  defmacro gteq(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:gteq, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds a less than or equal to constraint to a numeric field.

  ## Parameters
    * `value` - The maximum value (inclusive)

  ## Examples

      field :rating, :float do
        lteq(5.0)
      end

      field :percentage, :integer do
        gteq(0)
        lteq(100)
      end
  """
  @spec lteq(number()) :: Macro.t()
  defmacro lteq(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:lteq, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds a format constraint to a string field.

  ## Parameters
    * `value` - The format pattern (regular expression)

  ## Examples

      field :email, :string do
        format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
      end

      field :phone, :string do
        format(~r/^\+?[1-9]\d{1,14}$/)
      end
  """
  @spec format(Regex.t()) :: Macro.t()
  defmacro format(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:format, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds an enumeration constraint, limiting values to a predefined set.

  ## Parameters
    * `values` - List of allowed values

  ## Examples

      field :status, :string do
        choices(["pending", "active", "completed"])
      end

      field :priority, :integer do
        choices([1, 2, 3])
      end

      field :size, :string do
        choices(["small", "medium", "large"])
      end
  """
  @spec choices([term()]) :: Macro.t()
  defmacro choices(values) when is_list(values) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:choices, unquote(values)} | current_constraints
        ])
    end
  end

  @doc """
  Defines a field in the schema with a name, type, and optional constraints.

  ## Parameters
    * `name` - Atom representing the field name
    * `type` - The field's type, which can be:
      * A built-in type (`:string`, `:integer`, `:float`, `:boolean`, `:any`)
      * An array type (`{:array, type}`)
      * A map type (`{:map, {key_type, value_type}}`)
      * A union type (`{:union, [type1, type2, ...]}`)
      * A reference to another schema (atom)
    * `opts` - Optional block containing field constraints and metadata

  ## Examples

      # Simple field
      field :name, :string

      # Field with constraints
      field :age, :integer do
        description("User's age in years")
        gt(0)
        lt(150)
      end

      # Array field
      field :tags, {:array, :string} do
        min_items(1)
        max_items(10)
      end

      # Map field
      field :metadata, {:map, {:string, :any}}

      # Reference to another schema
      field :address, Address

      # Optional field with default
      field :active, :boolean do
        default(true)
      end
  """
  @spec field(atom(), term(), keyword()) :: Macro.t()
  defmacro field(name, type, opts \\ [do: {:__block__, [], []}])

  @spec field(atom(), term(), keyword()) :: Macro.t()
  defmacro field(name, type, do: block) do
    quote do
      field_meta = %Elixact.FieldMeta{
        name: unquote(name),
        type: unquote(handle_type(type)),
        required: true,
        constraints: []
      }

      # Create a variable accessible across all nested macros in this field block
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

  @doc """
  Sets a description for the field.

  ## Parameters
    * `text` - String description of the field's purpose or usage

  ## Examples

      field :age, :integer do
        description("User's age in years")
      end

      field :email, :string do
        description("Primary contact email address")
        format(~r/@/)
      end
  """
  @spec description(String.t()) :: Macro.t()
  defmacro description(text) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :description, unquote(text))
    end
  end

  @doc """
  Sets a single example value for the field.

  ## Parameters
    * `value` - An example value that would be valid for this field

  ## Examples

      field :age, :integer do
        example(25)
      end

      field :name, :string do
        example("John Doe")
      end
  """
  @spec example(term()) :: Macro.t()
  defmacro example(value) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :example, unquote(value))
    end
  end

  @doc """
  Sets multiple example values for the field.

  ## Parameters
    * `values` - List of example values that would be valid for this field

  ## Examples

      field :status, :string do
        examples(["pending", "active", "completed"])
      end

      field :score, :integer do
        examples([85, 92, 78])
      end
  """
  @spec examples([term()]) :: Macro.t()
  defmacro examples(values) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :examples, unquote(values))
    end
  end

  @doc """
  Marks the field as required (this is the default behavior).
  A required field must be present in the input data during validation.

  ## Examples

      field :email, :string do
        required()
        format(~r/@/)
      end

      field :name, :string do
        required()
        min_length(1)
      end
  """
  @spec required() :: Macro.t()
  defmacro required() do
    quote do
      var!(field_meta) =
        var!(field_meta)
        |> Map.put(:required, true)
    end
  end

  @doc """
  Marks the field as optional.
  An optional field may be omitted from the input data during validation.

  ## Examples

      field :middle_name, :string do
        optional()
      end

      field :bio, :string do
        optional()
        max_length(500)
      end
  """
  @spec optional() :: Macro.t()
  defmacro optional() do
    quote do
      var!(field_meta) =
        var!(field_meta)
        |> Map.put(:required, false)
    end
  end

  @doc """
  Sets a default value for the field and marks it as optional.
  The default value will be used if the field is omitted from input data.

  ## Parameters
    * `value` - The default value to use when the field is not provided

  ## Examples

      field :status, :string do
        default("pending")
      end

      field :active, :boolean do
        default(true)
      end

      field :retry_count, :integer do
        default(0)
        gteq(0)
      end
  """
  @spec default(term()) :: Macro.t()
  defmacro default(value) do
    quote do
      var!(field_meta) =
        var!(field_meta)
        |> Map.put(:default, unquote(value))
        |> Map.put(:required, false)
    end
  end

  # Handle type definitions
  @spec handle_type(term()) :: Macro.t()
  defp handle_type({:array, type}) do
    quote do
      Types.array(unquote(handle_type(type)))
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

  defp handle_type({:union, types}) do
    quote do
      Types.union(unquote(types |> Enum.map(&handle_type/1)))
    end
  end

  defp handle_type({:__aliases__, _, _} = module_alias) do
    quote do
      unquote(module_alias)
    end
  end

  # Handle built-in types and references
  defp handle_type(type) when is_atom(type) do
    if type in [:string, :integer, :float, :boolean, :any, :atom] do
      quote do
        Types.type(unquote(type))
      end
    else
      # Assume it's a reference
      {:ref, type}
    end
  end

  # Configuration block

  @doc """
  Defines configuration settings for the schema.

  Configuration options can include:
    * title - Schema title
    * description - Schema description
    * strict - Whether to enforce strict validation

  ## Examples

      config do
        title("User Schema")
        config_description("Validates user registration data")
        strict(true)
      end

      config do
        strict(false)
      end
  """
  @spec config(keyword()) :: Macro.t()
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
  @doc """
  Sets the title for the schema configuration.

  ## Parameters
    * `text` - String title for the schema

  ## Examples

      config do
        title("User Schema")
      end

      config do
        title("Product Validation Schema")
        strict(true)
      end
  """
  @spec title(String.t()) :: Macro.t()
  defmacro title(text) do
    quote do
      var!(config) = Map.put(var!(config), :title, unquote(text))
    end
  end

  @doc """
  Sets the description for the schema configuration.

  ## Parameters
    * `text` - String description of the schema

  ## Examples

      config do
        config_description("Validates user data for registration")
      end

      config do
        title("User Schema")
        config_description("Comprehensive user validation with email format checking")
      end
  """
  @spec config_description(String.t()) :: Macro.t()
  defmacro config_description(text) do
    quote do
      var!(config) = Map.put(var!(config), :description, unquote(text))
    end
  end

  @doc """
  Sets whether the schema should enforce strict validation.
  When strict is true, unknown fields will cause validation to fail.

  ## Parameters
    * `bool` - Boolean indicating if strict validation should be enabled

  ## Examples

      config do
        strict(true)
      end

      config do
        title("Flexible Schema")
        strict(false)
      end
  """
  @spec strict(boolean()) :: Macro.t()
  defmacro strict(bool) do
    quote do
      var!(config) = Map.put(var!(config), :strict, unquote(bool))
    end
  end
end
