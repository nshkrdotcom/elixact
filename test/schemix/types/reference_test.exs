defmodule Schemix.Types.ReferenceTest do
  use ExUnit.Case, async: true
  alias Schemix.{Types, Validator}

  defmodule AddressType do
    use Schemix.Type

    def type_definition do
      Types.map(Types.string(), Types.string())
    end

    def json_schema do
      %{
        "type" => "object",
        "properties" => %{
          "street" => %{"type" => "string"},
          "city" => %{"type" => "string"}
        }
      }
    end
  end

  test "validates using type reference" do
    type = Types.ref(AddressType)
    valid_data = %{"street" => "123 Main St", "city" => "Springfield"}

    assert {:ok, ^valid_data} = Validator.validate(type, valid_data)
    assert {:error, _} = Validator.validate(type, %{"street" => 123})
  end
end
