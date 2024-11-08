defmodule Schemix.JsonSchemaTest do
  use ExUnit.Case, async: true

  describe "basic schema conversion" do
    defmodule MetadataSchema do
      use Schemix

      schema "Schema with rich metadata" do
        field :name, :string do
          description("User's name")
          example("John Doe")
          required(true)
        end

        field :age, :integer do
          description("User's age")
          optional(true)
          default(18)
        end

        field :tags, {:array, :string} do
          description("User tags")
          examples(["admin", "user"])
          default([])
        end
      end
    end

    test "converts schema with rich metadata" do
      expected = %{
        "type" => "object",
        "description" => "Schema with rich metadata",
        "properties" => %{
          "name" => %{
            "type" => "string",
            "description" => "User's name",
            "examples" => ["John Doe"]
          },
          "age" => %{
            "type" => "integer",
            "description" => "User's age",
            "default" => 18
          },
          "tags" => %{
            "type" => "array",
            "items" => %{"type" => "string"},
            "description" => "User tags",
            "examples" => ["admin", "user"],
            "default" => []
          }
        },
        "required" => ["name"]
      }

      assert Schemix.JsonSchema.from_schema(MetadataSchema) == expected
    end
  end

  describe "schema configuration" do
    defmodule ConfiguredSchema do
      use Schemix

      schema "Configured schema" do
        field :name, :string do
          required(true)
        end

        field :data, {:map, {:string, :string}} do
          optional(true)
        end

        config do
          title("User Configuration")
          config_description("Configuration for user data")
          strict(true)
        end
      end
    end

    test "includes configuration in schema" do
      expected = %{
        "type" => "object",
        "title" => "User Configuration",
        "description" => "Configuration for user data",
        "additionalProperties" => false,
        "properties" => %{
          "name" => %{
            "type" => "string"
          },
          "data" => %{
            "type" => "object",
            "additionalProperties" => %{"type" => "string"}
          }
        },
        "required" => ["name"]
      }

      assert Schemix.JsonSchema.from_schema(ConfiguredSchema) == expected
    end
  end

  describe "custom type handling" do
    defmodule EmailType do
      use Schemix.Type

      def type_definition do
        Schemix.Types.string()
        |> Schemix.Types.with_constraints([
          {:format, ~r/^[^\s]+@[^\s]+$/}
        ])
      end

      def json_schema do
        %{
          "type" => "string",
          "format" => "email",
          "pattern" => "^[^\\s]+@[^\\s]+$"
        }
      end
    end

    defmodule SchemaWithCustomTypes do
      use Schemix

      schema "Schema with custom types" do
        field :email, EmailType do
          required(true)
          description("User's email address")
        end

        field :backup_email, EmailType do
          optional(true)
          description("Backup email address")
        end
      end
    end

    test "handles custom types correctly" do
      expected = %{
        "type" => "object",
        "description" => "Schema with custom types",
        "properties" => %{
          "email" => %{
            "type" => "string",
            "format" => "email",
            "pattern" => "^[^\\s]+@[^\\s]+$",
            "description" => "User's email address"
          },
          "backup_email" => %{
            "type" => "string",
            "format" => "email",
            "pattern" => "^[^\\s]+@[^\\s]+$",
            "description" => "Backup email address"
          }
        },
        "required" => ["email"]
      }

      assert Schemix.JsonSchema.from_schema(SchemaWithCustomTypes) == expected
    end
  end

  describe "schema references" do
    defmodule AddressSchema do
      use Schemix

      schema "Address information" do
        field :street, :string do
          required(true)
        end

        field :city, :string do
          required(true)
        end

        field :country, :string do
          required(true)
        end
      end
    end

    defmodule ContactSchema do
      use Schemix

      schema "Contact information" do
        field :primary_address, AddressSchema do
          required(true)
        end

        field :shipping_address, AddressSchema do
          optional(true)
        end
      end
    end

    defmodule CircularSchema do
      use Schemix

      schema "Schema with circular reference" do
        field :name, :string do
          required(true)
        end

        field :parent, CircularSchema do
          optional(true)
        end

        field :children, {:array, CircularSchema} do
          optional(true)
        end
      end
    end

    test "handles schema references" do
      expected = %{
        "type" => "object",
        "description" => "Contact information",
        "properties" => %{
          "primary_address" => %{
            "$ref" => "#/definitions/AddressSchema"
          },
          "shipping_address" => %{
            "$ref" => "#/definitions/AddressSchema"
          }
        },
        "required" => ["primary_address"],
        "definitions" => %{
          "AddressSchema" => %{
            "type" => "object",
            "description" => "Address information",
            "properties" => %{
              "street" => %{"type" => "string"},
              "city" => %{"type" => "string"},
              "country" => %{"type" => "string"}
            },
            "required" => ["street", "city", "country"]
          }
        }
      }

      assert Schemix.JsonSchema.from_schema(ContactSchema) == expected
    end

    test "handles circular references" do
      expected = %{
        "type" => "object",
        "description" => "Schema with circular reference",
        "properties" => %{
          "name" => %{"type" => "string"},
          "parent" => %{"$ref" => "#/definitions/CircularSchema"},
          "children" => %{
            "type" => "array",
            "items" => %{"$ref" => "#/definitions/CircularSchema"}
          }
        },
        "required" => ["name"],
        "definitions" => %{
          "CircularSchema" => %{
            "type" => "object",
            "description" => "Schema with circular reference",
            "properties" => %{
              "name" => %{"type" => "string"},
              "parent" => %{"$ref" => "#/definitions/CircularSchema"},
              "children" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/definitions/CircularSchema"}
              }
            },
            "required" => ["name"]
          }
        }
      }

      assert Schemix.JsonSchema.from_schema(CircularSchema) == expected
    end
  end
end
