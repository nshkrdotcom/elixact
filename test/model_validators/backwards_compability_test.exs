defmodule Elixact.ModelValidatorBackwardsCompatibilityTest do
  use ExUnit.Case

  describe "backwards compatibility" do
    test "existing schemas without model validators work unchanged" do
      defmodule LegacySchemaTest do
        use Elixact, define_struct: true

        schema do
          field :name, :string, required: true
          field :age, :integer, optional: true
        end
      end

      data = %{name: "Test User", age: 30}

      assert {:ok, result} = LegacySchemaTest.validate(data)
      assert %LegacySchemaTest{} = result
      assert result.name == "Test User"
      assert result.age == 30
    end

    test "existing validation behavior unchanged" do
      defmodule LegacyValidationTest do
        use Elixact

        schema do
          field :email, :string do
            required()
            format(~r/@/)
          end
        end
      end

      # Valid case
      assert {:ok, result} = LegacyValidationTest.validate(%{email: "test@example.com"})
      assert result.email == "test@example.com"

      # Invalid case
      assert {:error, errors} = LegacyValidationTest.validate(%{email: "invalid"})
      assert length(errors) == 1
      assert hd(errors).code == :format
    end

    test "existing __schema__ introspection unchanged for schemas without model validators" do
      defmodule IntrospectionTest do
        use Elixact

        schema "Test schema" do
          field :test_field, :string, required: true
        end
      end

      assert IntrospectionTest.__schema__(:description) == "Test schema"
      assert is_list(IntrospectionTest.__schema__(:fields))
      assert IntrospectionTest.__schema__(:model_validators) == []
    end

    test "Phase 1 struct functionality unchanged" do
      defmodule StructCompatTest do
        use Elixact, define_struct: true

        schema do
          field :value, :string, required: true
        end
      end

      data = %{value: "test"}

      # Validation returns struct
      assert {:ok, result} = StructCompatTest.validate(data)
      assert %StructCompatTest{} = result

      # Dump works
      assert {:ok, dumped} = StructCompatTest.dump(result)
      assert dumped == %{value: "test"}

      # Introspection works
      assert StructCompatTest.__struct_enabled__?()
      assert StructCompatTest.__struct_fields__() == [:value]
    end
  end
end
