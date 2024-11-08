defmodule Schemix do
  defmacro __using__(_opts) do
    quote do
      import Schemix.Schema
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :validations, accumulate: true)
      Module.register_attribute(__MODULE__, :config, [])
      @before_compile Schemix
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Basic API functions to be implemented
      def validate(data), do: Schemix.Validator.validate(__MODULE__, data)
      def json_schema(), do: Schemix.JsonSchema.generate(__MODULE__)
    end
  end
end
