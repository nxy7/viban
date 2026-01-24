defmodule VibanWeb.BoardChannel do
  @moduledoc """
  Phoenix Channel for board-level events.

  Handles real-time communication for board-wide events like client actions
  triggered by hooks.

  ## Topics

  - `board:{board_id}` - Board-specific events

  ## Events

  ### Incoming (client -> server)
  - `move_task` - Move a task to a new column/position
    - `task_id: string` - ID of the task to move
    - `column_id: string` - Target column ID
    - `prev_task_id: string | null` - Task above the new position
    - `next_task_id: string | null` - Task below the new position

  ### Outgoing (server -> client)
  - `task_changed` - A task was created, updated, or deleted
    - `task: map` - The task data
    - `action: string` - The action that was performed (create, update, move, destroy)
  - `hook_executed` - A hook was executed on a task
    - `hook_id: string` - The hook identifier (e.g., "system:play-sound")
    - `hook_name: string` - Human-readable hook name
    - `task_id: string` - The task the hook executed on
    - `triggering_column_id: string` - The column that triggered the hook
    - `result: string` - "ok" or "error"
    - `effects: map` - Hook-specific effects (e.g., `%{play_sound: %{sound: "ding"}}`)
  """

  use Phoenix.Channel

  alias Viban.Kanban.Task

  require Logger

  @impl true
  def join("board:" <> board_id, _params, socket) do
    Logger.debug("[BoardChannel] Client joined board:#{board_id}")

    # Subscribe to PubSub topic for task changes
    Phoenix.PubSub.subscribe(Viban.PubSub, "kanban_lite:board:#{board_id}")

    {:ok, assign(socket, :board_id, board_id)}
  end

  @impl true
  def handle_info({:task_changed, %{task: task, action: action}}, socket) do
    Logger.info("[BoardChannel] Broadcasting task_changed: action=#{action} task=#{task.id}")

    push(socket, "task_changed", %{
      task: serialize_task(task),
      action: to_string(action)
    })

    {:noreply, socket}
  end

  def handle_info({:hook_executed, payload}, socket) do
    Logger.info("[BoardChannel] Broadcasting hook_executed: #{payload.hook_name}")

    push(socket, "hook_executed", serialize_hook_execution(payload))

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_in("move_task", params, socket) do
    task_id = params["task_id"]
    column_id = params["column_id"]
    prev_task_id = params["prev_task_id"]
    next_task_id = params["next_task_id"]

    Logger.info("[BoardChannel] move_task: task=#{task_id} to column=#{column_id} prev=#{prev_task_id} next=#{next_task_id}")

    case Task.get(task_id) do
      {:ok, task} ->
        move_params = %{
          column_id: column_id,
          after_task_id: normalize_id(prev_task_id),
          before_task_id: normalize_id(next_task_id)
        }

        case Task.move(task, move_params) do
          {:ok, _updated_task} ->
            Logger.info("[BoardChannel] Task #{task_id} moved successfully")
            {:reply, {:ok, %{status: "moved"}}, socket}

          {:error, error} ->
            Logger.error("[BoardChannel] Failed to move task: #{inspect(error)}")
            {:reply, {:error, %{reason: "move_failed", details: inspect(error)}}, socket}
        end

      {:error, _} ->
        {:reply, {:error, %{reason: "task_not_found"}}, socket}
    end
  end

  defp normalize_id(nil), do: nil
  defp normalize_id(""), do: nil
  defp normalize_id("null"), do: nil
  defp normalize_id(id) when is_binary(id), do: id

  defp serialize_task(task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      column_id: task.column_id,
      position: task.position,
      parent_task_id: task.parent_task_id,
      worktree_path: task.worktree_path,
      worktree_branch: task.worktree_branch,
      agent_status: task.agent_status && to_string(task.agent_status),
      pr_url: task.pr_url,
      pr_status: task.pr_status && to_string(task.pr_status),
      inserted_at: task.inserted_at && DateTime.to_iso8601(task.inserted_at),
      updated_at: task.updated_at && DateTime.to_iso8601(task.updated_at)
    }
  end

  defp serialize_hook_execution(payload) do
    %{
      hook_id: payload.hook_id,
      hook_name: payload.hook_name,
      task_id: payload.task_id,
      triggering_column_id: payload.triggering_column_id,
      result: to_string(payload.result),
      effects: payload.effects
    }
  end
end
