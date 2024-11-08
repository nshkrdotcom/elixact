defmodule Schemix.Type do
  @moduledoc """
  Behaviour and macros for defining custom types.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Schemix.Type
      import Schemix.Types

      def validate(value) do
        validate_type(type_definition(), value)
      end

      defp validate_type({:type, type_name, constraints}, value) do
        with {:ok, value} <- Schemix.Types.validate(type_name, value) do
          validate_constraints(value, constraints)
        end
      end

      defp validate_constraints(value, []), do: {:ok, value}

      defp validate_constraints(value, [{constraint, args} | rest]) do
        # Ensure args is always a list
        args_list = List.wrap(args)

        case apply(__MODULE__, constraint, [value | args_list]) do
          true -> validate_constraints(value, rest)
          false -> {:error, "failed #{constraint} constraint"}
        end
      end
    end
  end

  @callback type_definition() :: Schemix.Types.type_definition()
  @callback json_schema() :: map()
end
