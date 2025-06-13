defmodule Elixact.JsonSchema.ReferenceStore do
  @moduledoc """
  Manages schema references and definitions for JSON Schema generation.

  This module provides a stateful store for tracking schema references
  and their corresponding JSON Schema definitions during conversion.
  """

  @type state :: %{
          refs: MapSet.t(module()),
          definitions: %{String.t() => map()}
        }

  @doc """
  Starts a new reference store process.

  ## Returns
    * `{:ok, pid}` on success

  ## Examples

      iex> {:ok, store} = Elixact.JsonSchema.ReferenceStore.start_link()
      {:ok, #PID<...>}
  """
  @spec start_link() :: {:ok, pid()}
  def start_link do
    Agent.start_link(fn ->
      %{
        refs: MapSet.new(),
        definitions: %{}
      }
    end)
  end

  @doc """
  Stops the reference store process.

  ## Parameters
    * `agent` - The reference store process PID

  ## Examples

      iex> {:ok, store} = Elixact.JsonSchema.ReferenceStore.start_link()
      iex> Elixact.JsonSchema.ReferenceStore.stop(store)
      :ok
  """
  @spec stop(pid()) :: :ok
  def stop(agent) do
    Agent.stop(agent)
  end

  @doc """
  Adds a schema module reference to track for processing.

  ## Parameters
    * `agent` - The reference store process PID
    * `module` - The schema module to add as a reference

  ## Examples

      iex> Elixact.JsonSchema.ReferenceStore.add_reference(store, MySchema)
      :ok
  """
  @spec add_reference(pid(), module()) :: :ok
  def add_reference(agent, module) when is_atom(module) do
    Agent.update(agent, fn state ->
      %{state | refs: MapSet.put(state.refs, module)}
    end)
  end

  @spec get_references(pid()) :: [module()]
  def get_references(agent) do
    Agent.get(agent, fn state ->
      MapSet.to_list(state.refs)
    end)
  end

  @spec has_reference?(pid(), module()) :: boolean()
  def has_reference?(agent, module) do
    Agent.get(agent, fn state ->
      MapSet.member?(state.refs, module)
    end)
  end

  @spec add_definition(pid(), module(), map()) :: :ok
  def add_definition(agent, module, schema) do
    Agent.update(agent, fn state ->
      %{state | definitions: Map.put(state.definitions, module_name(module), schema)}
    end)
  end

  @spec has_definition?(pid(), module()) :: boolean()
  def has_definition?(agent, module) do
    Agent.get(agent, fn state ->
      Map.has_key?(state.definitions, module_name(module))
    end)
  end

  @spec get_definitions(pid()) :: %{String.t() => map()}
  def get_definitions(agent) do
    Agent.get(agent, fn state -> state.definitions end)
  end

  @spec ref_path(module()) :: String.t()
  def ref_path(module) do
    "#/definitions/#{module_name(module)}"
  end

  @spec module_name(module()) :: String.t()
  defp module_name(module) do
    cond do
      is_atom(module) ->
        # Handle plain atoms by converting to string and extracting last part
        module
        |> Atom.to_string()
        |> String.replace_prefix("Elixir.", "")
        |> String.split(".")
        |> List.last()

      true ->
        # Handle actual modules
        module
        |> Module.split()
        |> List.last()
    end
  end
end
