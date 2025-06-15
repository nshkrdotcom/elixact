defmodule Elixact.Runtime.DynamicSchema do
  @moduledoc """
  Represents a schema created at runtime with field definitions and configuration.
  
  This struct holds all the information needed to validate data against a 
  dynamically created schema, including field metadata, configuration options,
  and runtime metadata.
  """

  @enforce_keys [:name, :fields, :config]
  defstruct [
    :name,           # String - Unique identifier for the schema
    :fields,         # Map - Field name -> FieldMeta mapping  
    :config,         # Map - Schema configuration options
    :metadata        # Map - Runtime metadata (creation time, etc.)
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          fields: %{atom() => Elixact.FieldMeta.t()},
          config: %{
            optional(:title) => String.t(),
            optional(:description) => String.t(),
            optional(:strict) => boolean()
          },
          metadata: map()
        }

  @doc """
  Creates a new DynamicSchema instance.

  ## Parameters
    * `name` - Unique identifier for the schema
    * `fields` - Map of field name to FieldMeta
    * `config` - Schema configuration options
    * `metadata` - Optional runtime metadata

  ## Examples

      iex> fields = %{name: %Elixact.FieldMeta{...}}
      iex> config = %{title: "User Schema", strict: true}
      iex> Elixact.Runtime.DynamicSchema.new("UserSchema", fields, config)
      %Elixact.Runtime.DynamicSchema{...}
  """
  @spec new(String.t(), map(), map(), map()) :: t()
  def new(name, fields, config, metadata \\ %{}) do
    %__MODULE__{
      name: name,
      fields: fields,
      config: config,
      metadata: Map.merge(%{
        created_at: DateTime.utc_now(),
        field_count: map_size(fields)
      }, metadata)
    }
  end

  @doc """
  Gets the field definition for a specific field name.

  ## Parameters
    * `schema` - The DynamicSchema instance
    * `field_name` - The field name (atom)

  ## Returns
    * `{:ok, field_meta}` if field exists
    * `:error` if field not found

  ## Examples

      iex> Elixact.Runtime.DynamicSchema.get_field(schema, :name)
      {:ok, %Elixact.FieldMeta{...}}

      iex> Elixact.Runtime.DynamicSchema.get_field(schema, :nonexistent)
      :error
  """
  @spec get_field(t(), atom()) :: {:ok, Elixact.FieldMeta.t()} | :error
  def get_field(%__MODULE__{fields: fields}, field_name) do
    case Map.get(fields, field_name) do
      nil -> :error
      field_meta -> {:ok, field_meta}
    end
  end

  @doc """
  Lists all field names in the schema.

  ## Parameters
    * `schema` - The DynamicSchema instance

  ## Returns
    * List of field names (atoms)

  ## Examples

      iex> Elixact.Runtime.DynamicSchema.field_names(schema)
      [:name, :age, :email]
  """
  @spec field_names(t()) :: [atom()]
  def field_names(%__MODULE__{fields: fields}) do
    Map.keys(fields)
  end

  @doc """
  Gets the required field names from the schema.

  ## Parameters
    * `schema` - The DynamicSchema instance

  ## Returns
    * List of required field names (atoms)

  ## Examples

      iex> Elixact.Runtime.DynamicSchema.required_fields(schema)
      [:name, :email]
  """
  @spec required_fields(t()) :: [atom()]
  def required_fields(%__MODULE__{fields: fields}) do
    fields
    |> Enum.filter(fn {_, meta} -> meta.required end)
    |> Enum.map(fn {name, _} -> name end)
  end

  @doc """
  Gets the optional field names from the schema.

  ## Parameters
    * `schema` - The DynamicSchema instance

  ## Returns
    * List of optional field names (atoms)

  ## Examples

      iex> Elixact.Runtime.DynamicSchema.optional_fields(schema)
      [:age, :bio]
  """
  @spec optional_fields(t()) :: [atom()]
  def optional_fields(%__MODULE__{fields: fields}) do
    fields
    |> Enum.filter(fn {_, meta} -> not meta.required end)
    |> Enum.map(fn {name, _} -> name end)
  end

  @doc """
  Checks if the schema is configured for strict validation.

  ## Parameters
    * `schema` - The DynamicSchema instance

  ## Returns
    * `true` if strict mode is enabled, `false` otherwise

  ## Examples

      iex> Elixact.Runtime.DynamicSchema.strict?(schema)
      true
  """
  @spec strict?(t()) :: boolean()
  def strict?(%__MODULE__{config: config}) do
    Map.get(config, :strict, false)
  end

  @doc """
  Updates the schema configuration.

  ## Parameters
    * `schema` - The DynamicSchema instance
    * `new_config` - Configuration options to merge

  ## Returns
    * Updated DynamicSchema instance

  ## Examples

      iex> updated = Elixact.Runtime.DynamicSchema.update_config(schema, %{strict: true})
      %Elixact.Runtime.DynamicSchema{config: %{strict: true, ...}}
  """
  @spec update_config(t(), map()) :: t()
  def update_config(%__MODULE__{} = schema, new_config) do
    %{schema | config: Map.merge(schema.config, new_config)}
  end

  @doc """
  Adds a new field to the schema.

  ## Parameters
    * `schema` - The DynamicSchema instance
    * `field_name` - The field name (atom)
    * `field_meta` - The FieldMeta definition

  ## Returns
    * Updated DynamicSchema instance

  ## Examples

      iex> field_meta = %Elixact.FieldMeta{name: :bio, type: {:type, :string, []}, required: false}
      iex> updated = Elixact.Runtime.DynamicSchema.add_field(schema, :bio, field_meta)
      %Elixact.Runtime.DynamicSchema{...}
  """
  @spec add_field(t(), atom(), Elixact.FieldMeta.t()) :: t()
  def add_field(%__MODULE__{} = schema, field_name, field_meta) do
    updated_fields = Map.put(schema.fields, field_name, field_meta)
    updated_metadata = Map.put(schema.metadata, :field_count, map_size(updated_fields))
    
    %{schema | 
      fields: updated_fields,
      metadata: updated_metadata
    }
  end

  @doc """
  Removes a field from the schema.

  ## Parameters
    * `schema` - The DynamicSchema instance
    * `field_name` - The field name to remove (atom)

  ## Returns
    * Updated DynamicSchema instance

  ## Examples

      iex> updated = Elixact.Runtime.DynamicSchema.remove_field(schema, :bio)
      %Elixact.Runtime.DynamicSchema{...}
  """
  @spec remove_field(t(), atom()) :: t()
  def remove_field(%__MODULE__{} = schema, field_name) do
    updated_fields = Map.delete(schema.fields, field_name)
    updated_metadata = Map.put(schema.metadata, :field_count, map_size(updated_fields))
    
    %{schema | 
      fields: updated_fields,
      metadata: updated_metadata
    }
  end

  @doc """
  Returns a summary of the schema structure.

  ## Parameters
    * `schema` - The DynamicSchema instance

  ## Returns
    * Map with schema summary information

  ## Examples

      iex> Elixact.Runtime.DynamicSchema.summary(schema)
      %{
        name: "UserSchema",
        field_count: 3,
        required_count: 2,
        optional_count: 1,
        strict: true
      }
  """
  @spec summary(t()) :: map()
  def summary(%__MODULE__{} = schema) do
    required = required_fields(schema)
    optional = optional_fields(schema)
    
    %{
      name: schema.name,
      field_count: length(required) + length(optional),
      required_count: length(required),
      optional_count: length(optional),
      strict: strict?(schema),
      created_at: Map.get(schema.metadata, :created_at)
    }
  end
end
