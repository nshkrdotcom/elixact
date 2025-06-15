defmodule Elixact.TypeAdapterTest do
  use ExUnit.Case, async: true

  alias Elixact.TypeAdapter

  describe "validate/3" do
    test "validates basic types" do
      assert {:ok, "hello"} = TypeAdapter.validate(:string, "hello")
      assert {:ok, 42} = TypeAdapter.validate(:integer, 42)
      assert {:ok, true} = TypeAdapter.validate(:boolean, true)
    end

    test "validates complex types" do
      assert {:ok, [1, 2, 3]} = TypeAdapter.validate({:array, :integer}, [1, 2, 3])
      assert {:ok, %{"a" => 1}} = TypeAdapter.validate({:map, {:string, :integer}}, %{"a" => 1})
    end

    test "handles type coercion" do
      assert {:ok, 123} = TypeAdapter.validate(:integer, "123", coerce: true)
      assert {:ok, "42"} = TypeAdapter.validate(:string, 42, coerce: true)
    end

    # Add 9 more tests...
  end

  # Add dump and json_schema tests...
end
