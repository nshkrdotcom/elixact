defmodule Schemix do
  @moduledoc """
  Schemix is a schema definition and validation library for Elixir.

  It provides a DSL for defining schemas with rich metadata, validation rules,
  and JSON Schema generation capabilities.

  ## Example

      defmodule UserSchema do
        use Schemix

        schema "User account information" do
          field :name, :string do
            description "User's full name"
            example "John Doe"
            required true
            min_length 2
          end

          field :age, :integer do
            description "User's age in years"
            optional true
            gt 0
            lt 150
          end

          field :email, Types.Email do
            description "User's email address"
            required true
          end

          config do
            title "User Schema"
            strict true
          end
        end
      end

  The schema can then be used for validation and JSON Schema generation:

      # Validation
      {:ok, user} = UserSchema.validate(%{
        name: "John Doe",
        email: "john@example.com",
        age: 30
      })

      # JSON Schema generation
      json_schema = UserSchema.json_schema()
  """

  @doc """
  Configures a module to be a Schemix schema.

  This macro sets up the necessary module attributes and imports
  the schema DSL functions.
  """
  defmacro __using__(_opts) do
    quote do
      import Schemix.Schema

      # Register accumulating attributes
      Module.register_attribute(__MODULE__, :schema_description, [])
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :validations, accumulate: true)
      Module.register_attribute(__MODULE__, :config, [])

      @before_compile Schemix
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __schema__(:description), do: @schema_description
      def __schema__(:fields), do: @fields
      def __schema__(:validations), do: @validations
      def __schema__(:config), do: @config
    end
  end
end
