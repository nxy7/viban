defmodule Viban.Jido.Actions.Task.Initialize do
  use Jido.Action,
    name: "task_initialize",
    description: "Initialize a task agent: create worktree, self-heal, queue column hooks",
    schema: [
      board_id: [type: :string, required: true],
      task_id: [type: :string, required: true],
      column_id: [type: :string],
      worktree_path: [type: :string],
      worktree_branch: [type: :string],
      custom_branch_name: [type: :string]
    ]

  alias Viban.Kanban.HookExecution
  alias Viban.Kanban.Task
  alias Viban.Kanban.Task.WorktreeManager

  require Logger

  def run(params, _context) do
    task_id = params.task_id
    board_id = params.board_id

    {worktree_path, worktree_branch} =
      if is_nil(params[:worktree_path]) do
        create_worktree(board_id, task_id, params[:custom_branch_name])
      else
        {params[:worktree_path], params[:worktree_branch]}
      end

    self_heal(task_id)

    {:ok,
     %{
       worktree_path: worktree_path,
       worktree_branch: worktree_branch,
       status: :initialized
     }}
  end

  defp create_worktree(board_id, task_id, custom_branch_name) do
    case WorktreeManager.create_worktree(board_id, task_id, custom_branch_name) do
      {:ok, path, branch} ->
        case Task.get(task_id) do
          {:ok, task} ->
            Task.assign_worktree(task, %{worktree_path: path, worktree_branch: branch})

          _ ->
            :ok
        end

        {path, branch}

      {:error, reason} ->
        Logger.warning("[TaskAgent.Initialize] Failed to create worktree: #{inspect(reason)}")
        {nil, nil}
    end
  end

  defp self_heal(task_id) do
    case HookExecution.active_for_task(task_id) do
      {:ok, executions} ->
        {running, _pending} = Enum.split_with(executions, &(&1.status == :running))

        Enum.each(running, fn exec ->
          HookExecution.cancel(exec, %{skip_reason: :server_restart})
        end)

      {:error, _reason} ->
        :ok
    end
  end
end
