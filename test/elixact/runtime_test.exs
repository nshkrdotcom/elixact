defmodule Elixact.RuntimeTest do
  use ExUnit.Case, async: true

  alias Elixact.Runtime
  alias Elixact.Runtime.DynamicSchema

  describe "create_schema/2" do
    test "creates schema with basic field definitions" do
      fields = [
        {:name, :string, [required: true, min_length: 2]},
        {:age, :integer, [optional: true, gt: 0]}
      ]

      schema = Runtime.create_schema(fields, title: "User Schema")

      assert %DynamicSchema{} = schema
      assert schema.config[:title] == "User Schema"
      assert map_size(schema.fields) == 2
    end

    test "handles complex nested types" do
      fields = [
        {:data, {:array, :string}, [min_items: 1]},
        {:metadata, {:map, {:string, :any}}, []}
      ]

      schema = Runtime.create_schema(fields)
      assert %DynamicSchema{} = schema
    end

    # Add 12 more tests as specified in test list...
  end

  describe "validate/3" do
    test "validates against runtime schema successfully" do
      schema = Runtime.create_schema([{:name, :string, [required: true]}])
      data = %{name: "John"}

      assert {:ok, %{name: "John"}} = Runtime.validate(data, schema)
    end

    # Add more validation tests...
  end

  # Add to_json_schema tests...
end
