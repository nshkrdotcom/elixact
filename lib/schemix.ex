defmodule Schemix do
  defmacro __using__(_opts) do
    quote do
      import Schemix.Schema

      # Register accumulating attributes
      Module.register_attribute(__MODULE__, :schema_description, persist: true)
      Module.register_attribute(__MODULE__, :fields, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :validations, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :config, persist: true)

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
