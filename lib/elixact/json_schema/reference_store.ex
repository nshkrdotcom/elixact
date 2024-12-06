defmodule Elixact.JsonSchema.ReferenceStore do
  @moduledoc """
  Manages schema references and definitions for JSON Schema generation.
  """

  def start_link do
    Agent.start_link(fn ->
      %{
        refs: MapSet.new(),
        definitions: %{}
      }
    end)
  end

  def stop(agent) do
    Agent.stop(agent)
  end

  def add_reference(agent, module) when is_atom(module) do
    Agent.update(agent, fn state ->
      %{state | refs: MapSet.put(state.refs, module)}
    end)
  end

  def get_references(agent) do
    Agent.get(agent, fn state ->
      MapSet.to_list(state.refs)
    end)
  end

  def has_reference?(agent, module) do
    Agent.get(agent, fn state ->
      MapSet.member?(state.refs, module)
    end)
  end

  def add_definition(agent, module, schema) do
    Agent.update(agent, fn state ->
      %{state | definitions: Map.put(state.definitions, module_name(module), schema)}
    end)
  end

  def has_definition?(agent, module) do
    Agent.get(agent, fn state ->
      Map.has_key?(state.definitions, module_name(module))
    end)
  end

  def get_definitions(agent) do
    Agent.get(agent, fn state -> state.definitions end)
  end

  def ref_path(module) do
    "#/definitions/#{module_name(module)}"
  end

  defp module_name(module) do
    module
    |> Module.split()
    |> List.last()
  end
end
