defmodule Schemix.IntegrationTest do
  use ExUnit.Case, async: true

  defmodule UserSchema do
    use Schemix

    schema "User account information" do
      field :email, Types.Email do
        required(true)
        description("User's email address")
      end

      field :age, :integer do
        optional(true)
        gt(0)
        lt(150)
      end

      field :tags, {:array, :string} do
        description("User tags")
        default([])
        min_items(0)
        items(min_length: 1)
      end
    end
  end

  describe "schema validation" do
    test "validates correct data" do
      valid_data = %{
        email: "test@example.com",
        age: 25,
        tags: ["tag1", "tag2"]
      }

      assert {:ok, _} = UserSchema.validate(valid_data)
    end

    test "rejects invalid email" do
      invalid_data = %{
        email: "not-an-email",
        age: 25
      }

      assert {:error, errors} = UserSchema.validate(invalid_data)
      assert length(errors) > 0
    end

    test "rejects invalid age" do
      invalid_data = %{
        email: "test@example.com",
        age: 200
      }

      assert {:error, errors} = UserSchema.validate(invalid_data)
      assert length(errors) > 0
    end

    test "handles optional fields" do
      valid_data = %{
        email: "test@example.com"
      }

      assert {:ok, _} = UserSchema.validate(valid_data)
    end
  end
end
