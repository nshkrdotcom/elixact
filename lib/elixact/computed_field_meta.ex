defmodule Elixact.ComputedFieldMeta do
  @moduledoc """
  Metadata structure for computed fields in Elixact schemas.

  Computed fields are derived values that are calculated based on the validated
  data after field and model validation. They extend the validated result with
  additional computed information.
  """

  @enforce_keys [:name, :type, :function_name, :module]
  defstruct [
    :name,
    :type,
    :function_name,
    :module,
    :description,
    :example,
    :readonly
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: Elixact.Types.type_definition(),
          function_name: atom(),
          module: module(),
          description: String.t() | nil,
          example: term() | nil,
          readonly: boolean()
        }

  @doc """
  Creates a new ComputedFieldMeta struct.

  ## Parameters
    * `name` - The computed field name (atom)
    * `type` - The computed field type definition
    * `function_name` - The name of the function to call for computation
    * `module` - The module containing the computation function

  ## Examples

      iex> Elixact.ComputedFieldMeta.new(:full_name, {:type, :string, []}, :generate_full_name, MySchema)
      %Elixact.ComputedFieldMeta{
        name: :full_name,
        type: {:type, :string, []},
        function_name: :generate_full_name,
        module: MySchema,
        readonly: true
      }
  """
  @spec new(atom(), Elixact.Types.type_definition(), atom(), module()) :: t()
  def new(name, type, function_name, module) do
    %__MODULE__{
      name: name,
      type: type,
      function_name: function_name,
      module: module,
      readonly: true
    }
  end

  @doc """
  Updates the description of a computed field metadata.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct
    * `description` - The description text

  ## Examples

      iex> meta = Elixact.ComputedFieldMeta.new(:full_name, {:type, :string, []}, :generate_full_name, MySchema)
      iex> Elixact.ComputedFieldMeta.with_description(meta, "User's full name")
      %Elixact.ComputedFieldMeta{description: "User's full name", ...}
  """
  @spec with_description(t(), String.t()) :: t()
  def with_description(%__MODULE__{} = computed_field_meta, description) when is_binary(description) do
    %{computed_field_meta | description: description}
  end

  @doc """
  Adds an example value to a computed field metadata.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct
    * `example` - The example value

  ## Examples

      iex> meta = Elixact.ComputedFieldMeta.new(:full_name, {:type, :string, []}, :generate_full_name, MySchema)
      iex> Elixact.ComputedFieldMeta.with_example(meta, "John Doe")
      %Elixact.ComputedFieldMeta{example: "John Doe", ...}
  """
  @spec with_example(t(), term()) :: t()
  def with_example(%__MODULE__{} = computed_field_meta, example) do
    %{computed_field_meta | example: example}
  end

  @doc """
  Sets the readonly flag for a computed field metadata.

  While computed fields are readonly by default, this function allows
  explicit control over the readonly flag for special cases.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct
    * `readonly` - Whether the field should be marked as readonly

  ## Examples

      iex> meta = Elixact.ComputedFieldMeta.new(:full_name, {:type, :string, []}, :generate_full_name, MySchema)
      iex> Elixact.ComputedFieldMeta.set_readonly(meta, false)
      %Elixact.ComputedFieldMeta{readonly: false, ...}
  """
  @spec set_readonly(t(), boolean()) :: t()
  def set_readonly(%__MODULE__{} = computed_field_meta, readonly) when is_boolean(readonly) do
    %{computed_field_meta | readonly: readonly}
  end

  @doc """
  Validates that the computation function exists in the specified module.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct

  ## Returns
    * `:ok` if the function exists and has the correct arity
    * `{:error, reason}` if the function is invalid

  ## Examples

      iex> meta = Elixact.ComputedFieldMeta.new(:full_name, {:type, :string, []}, :generate_full_name, MySchema)
      iex> Elixact.ComputedFieldMeta.validate_function(meta)
      :ok  # assuming MySchema.generate_full_name/1 exists

      iex> meta = Elixact.ComputedFieldMeta.new(:bad_field, {:type, :string, []}, :missing_function, MySchema)
      iex> Elixact.ComputedFieldMeta.validate_function(meta)
      {:error, "Function MySchema.missing_function/1 is not defined"}
  """
  @spec validate_function(t()) :: :ok | {:error, String.t()}
  def validate_function(%__MODULE__{} = computed_field_meta) do
    if function_exported?(computed_field_meta.module, computed_field_meta.function_name, 1) do
      :ok
    else
      {:error, "Function #{computed_field_meta.module}.#{computed_field_meta.function_name}/1 is not defined"}
    end
  end

  @doc """
  Returns a string representation of the computed field function reference.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct

  ## Returns
    * String in the format "Module.function/arity"

  ## Examples

      iex> meta = Elixact.ComputedFieldMeta.new(:full_name, {:type, :string, []}, :generate_full_name, MySchema)
      iex> Elixact.ComputedFieldMeta.function_reference(meta)
      "MySchema.generate_full_name/1"
  """
  @spec function_reference(t()) :: String.t()
  def function_reference(%__MODULE__{} = computed_field_meta) do
    "#{computed_field_meta.module}.#{computed_field_meta.function_name}/1"
  end

  @doc """
  Converts computed field metadata to a map for debugging or serialization.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct

  ## Returns
    * Map representation of the computed field metadata

  ## Examples

      iex> meta = Elixact.ComputedFieldMeta.new(:full_name, {:type, :string, []}, :generate_full_name, MySchema)
      iex> |> Elixact.ComputedFieldMeta.with_description("User's full name")
      iex> Elixact.ComputedFieldMeta.to_map(meta)
      %{
        name: :full_name,
        type: {:type, :string, []},
        function_name: :generate_full_name,
        module: MySchema,
        description: "User's full name",
        example: nil,
        readonly: true,
        function_reference: "MySchema.generate_full_name/1"
      }
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = computed_field_meta) do
    %{
      name: computed_field_meta.name,
      type: computed_field_meta.type,
      function_name: computed_field_meta.function_name,
      module: computed_field_meta.module,
      description: computed_field_meta.description,
      example: computed_field_meta.example,
      readonly: computed_field_meta.readonly,
      function_reference: function_reference(computed_field_meta)
    }
  end
end
