defmodule Viban.Kanban.SystemHooks.Registry do
  @moduledoc """
  Registry of all available system hooks.
  System hooks are virtual - they exist in code, not in the database.
  """

  alias Viban.Kanban.SystemHooks.AutoStartHook
  alias Viban.Kanban.SystemHooks.ExecuteAIHook
  alias Viban.Kanban.SystemHooks.MoveTaskHook
  alias Viban.Kanban.SystemHooks.PlaySoundHook
  alias Viban.Kanban.SystemHooks.RefinePromptHook

  @system_hooks [
    AutoStartHook,
    ExecuteAIHook,
    RefinePromptHook,
    PlaySoundHook,
    MoveTaskHook
  ]

  @doc "Get all available system hooks"
  def all do
    Enum.map(@system_hooks, &to_hook_map/1)
  end

  @doc "Get a system hook by ID"
  def get(id) when is_binary(id) do
    case Enum.find(@system_hooks, fn hook -> hook.id() == id end) do
      nil -> {:error, :not_found}
      hook -> {:ok, to_hook_map(hook)}
    end
  end

  @doc "Check if an ID is a system hook"
  def system_hook?(id) when is_binary(id) do
    String.starts_with?(id, "system:")
  end

  def system_hook?(_), do: false

  @doc "Get the module for a system hook ID"
  def get_module(id) when is_binary(id) do
    Enum.find(@system_hooks, fn hook -> hook.id() == id end)
  end

  @doc "Execute a system hook"
  def execute(id, task, column, opts \\ []) do
    case get_module(id) do
      nil -> {:error, :not_found}
      module -> module.execute(task, column, opts)
    end
  end

  defp to_hook_map(module) do
    # Get default settings from module if defined, otherwise use defaults
    default_execute_once =
      if function_exported?(module, :default_execute_once, 0),
        do: module.default_execute_once(),
        else: false

    default_transparent =
      if function_exported?(module, :default_transparent, 0),
        do: module.default_transparent(),
        else: false

    %{
      id: module.id(),
      name: module.name(),
      description: module.description(),
      is_system: true,
      # System hooks don't have these DB-specific fields
      hook_kind: :system,
      command: nil,
      working_directory: nil,
      timeout_ms: nil,
      default_execute_once: default_execute_once,
      default_transparent: default_transparent
    }
  end
end
