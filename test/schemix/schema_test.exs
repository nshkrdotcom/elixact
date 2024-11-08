defmodule Schemix.SchemaTest do
  use ExUnit.Case, async: true

  describe "basic schema definition" do
    defmodule BasicSchema do
      use Schemix

      schema "Test schema" do
        field :name, :string do
          description("User's name")
          required(true)
        end

        field :age, :integer do
          description("User's age")
          optional(true)
        end
      end
    end

    test "stores schema description" do
      assert BasicSchema.__schema__(:description) == "Test schema"
    end

    test "registers fields correctly" do
      fields = BasicSchema.__schema__(:fields)

      assert {:name, name_meta} = Enum.find(fields, fn {name, _} -> name == :name end)
      assert {:age, age_meta} = Enum.find(fields, fn {name, _} -> name == :age end)

      # Required field
      assert name_meta.description == "User's name"
      assert name_meta.required == true
      assert name_meta.optional == false
      assert name_meta.type == {:type, :string, []}

      # Optional field
      assert age_meta.description == "User's age"
      assert age_meta.required == false
      assert age_meta.optional == true
      assert age_meta.type == {:type, :integer, []}
    end
  end

  describe "complex type definitions" do
    defmodule ComplexSchema do
      use Schemix

      schema do
        field :tags, {:array, :string} do
          description("List of tags")
          default([])
        end

        field :id, {:union, [:string, :integer]} do
          description("User ID")
          required(true)
        end
      end
    end

    test "handles array type correctly" do
      fields = ComplexSchema.__schema__(:fields)
      {:tags, tags_meta} = Enum.find(fields, fn {name, _} -> name == :tags end)

      assert tags_meta.type == {:array, :string, []}
      assert tags_meta.default == []
    end

    test "handles union type correctly" do
      fields = ComplexSchema.__schema__(:fields)
      {:id, id_meta} = Enum.find(fields, fn {name, _} -> name == :id end)

      assert id_meta.type == {:union, [:string, :integer], []}
      assert id_meta.required == true
    end
  end

  describe "validation rules" do
    defmodule ValidationSchema do
      use Schemix

      schema do
        field :password, :string do
          required(true)
        end

        field :password_confirmation, :string do
          required(true)
        end
      end

      def validate_passwords(data) do
        if data.password == data.password_confirmation do
          :ok
        else
          {:error, "passwords must match"}
        end
      end
    end

    test "validation function works" do
      valid_data = %{
        password: "secret",
        password_confirmation: "secret"
      }

      invalid_data = %{
        password: "secret",
        password_confirmation: "different"
      }

      assert :ok = ValidationSchema.validate_passwords(valid_data)
      assert {:error, "passwords must match"} = ValidationSchema.validate_passwords(invalid_data)
    end
  end
end
