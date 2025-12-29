defmodule Viban.Kanban.SystemHooks.ShellHook do
  @moduledoc """
  Base module for system hooks that run shell commands in worktrees.

  This module provides shared functionality for hooks that:
  1. Require a worktree to be present
  2. Detect the appropriate command based on project type
  3. Execute the command via HookRunner

  ## Usage

      defmodule MyHook do
        use Viban.Kanban.SystemHooks.ShellHook,
          id: "system:my-hook",
          name: "My Hook",
          description: "Does something useful",
          timeout_ms: 60_000

        @impl true
        def detect_command(worktree_path) do
          cond do
            File.exists?(Path.join(worktree_path, "mix.exs")) -> "mix my_task"
            true -> "echo 'No task configured'"
          end
        end
      end
  """

  @doc """
  Callback to detect the appropriate command for the given worktree.

  Must return a shell command string to execute.
  """
  @callback detect_command(worktree_path :: String.t()) :: String.t()

  defmacro __using__(opts) do
    hook_id = Keyword.fetch!(opts, :id)
    hook_name = Keyword.fetch!(opts, :name)
    hook_description = Keyword.fetch!(opts, :description)
    timeout_ms = Keyword.get(opts, :timeout_ms, 60_000)

    quote do
      @behaviour Viban.Kanban.SystemHooks.Behaviour
      @behaviour Viban.Kanban.SystemHooks.ShellHook

      require Logger

      alias Viban.Kanban.Actors.HookRunner

      @impl Viban.Kanban.SystemHooks.Behaviour
      def id, do: unquote(hook_id)

      @impl Viban.Kanban.SystemHooks.Behaviour
      def name, do: unquote(hook_name)

      @impl Viban.Kanban.SystemHooks.Behaviour
      def description, do: unquote(hook_description)

      @impl Viban.Kanban.SystemHooks.Behaviour
      def execute(task, _column, _opts) do
        worktree_path = task.worktree_path

        if worktree_path && File.dir?(worktree_path) do
          run_in_worktree(task, worktree_path)
        else
          Logger.warning("[#{unquote(hook_id)}] No worktree available for task #{task.id}")
          :ok
        end
      end

      defp run_in_worktree(task, worktree_path) do
        command = detect_command(worktree_path)
        Logger.info("[#{unquote(hook_id)}] Running '#{command}' for task #{task.id}")

        hook_config = %{
          name: unquote(hook_id),
          command: command,
          working_directory: :worktree,
          timeout_ms: unquote(timeout_ms)
        }

        case HookRunner.run_once(hook_config, worktree_path) do
          {:ok, _output} ->
            Logger.info("[#{unquote(hook_id)}] Completed successfully for task #{task.id}")
            :ok

          {:error, reason} ->
            Logger.error("[#{unquote(hook_id)}] Failed for task #{task.id}: #{inspect(reason)}")
            {:error, reason}
        end
      end

      defoverridable execute: 3
    end
  end
end
