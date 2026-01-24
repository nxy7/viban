defmodule VibanWeb.Hologram.Components.Column do
  use Hologram.Component

  alias VibanWeb.Hologram.Components.TaskCard

  prop :column, :map, required: true
  prop :tasks, :list, default: []
  prop :search_query, :string, default: ""
  prop :hovered_task_id, :string, default: nil
  prop :all_tasks, :list, default: []
  prop :is_first_column, :boolean, default: false
  prop :tasks_version, :integer, default: 0

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="flex flex-col w-80 flex-shrink-0 h-full bg-gray-900/50 rounded-xl border border-gray-800" data-kanban-column={@column.id} data-tasks-version={@tasks_version}>
      <div class="flex items-center justify-between p-3 border-b border-gray-800">
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded-full" style={color_style(@column.color)}></div>
          <h3 class="font-medium text-white">{@column.name}</h3>
          <span class="text-xs text-gray-500 bg-gray-800 px-2 py-0.5 rounded-full">
            {length(@tasks)}
          </span>
        </div>
        <div class="flex items-center gap-1">
          <button
            class="p-1 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
            data-column-settings={@column.id}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" />
            </svg>
          </button>
        </div>
      </div>

      <div class="flex-1 overflow-y-auto p-2 space-y-2" data-task-list>
        {%for task <- filtered_tasks(@tasks, @search_query)}
          <TaskCard task={task} glow_state={compute_glow_state(task, @hovered_task_id, @all_tasks)} all_tasks={@all_tasks} />
        {/for}
      </div>

      {%if @is_first_column}
        <div class="p-2 border-t border-gray-800">
          <button
            class="w-full flex items-center justify-center gap-2 p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors text-sm"
            data-create-task
            data-create-task-column-id={@column.id}
            data-create-task-column-name={@column.name}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            Create new task
          </button>
        </div>
      {/if}
    </div>
    """
  end


  defp color_style(color) do
    "background-color: " <> (color || "#6366f1")
  end

  defp filtered_tasks(tasks, ""), do: tasks
  defp filtered_tasks(tasks, nil), do: tasks
  defp filtered_tasks(tasks, query) do
    query_lower = String.downcase(query)
    Enum.filter(tasks, fn task ->
      String.contains?(String.downcase(task.title || ""), query_lower) ||
        String.contains?(String.downcase(task.description || ""), query_lower)
    end)
  end

  defp compute_glow_state(_task, nil, _all_tasks), do: nil
  defp compute_glow_state(task, hovered_task_id, all_tasks) do
    task_id = task[:id] || task.id
    hovered_task = Enum.find(all_tasks, fn t -> (t[:id] || t.id) == hovered_task_id end)

    cond do
      hovered_task == nil ->
        nil

      (hovered_task[:is_parent] || hovered_task.is_parent) ->
        cond do
          task_id == hovered_task_id -> "parent"
          (task[:parent_task_id] || task.parent_task_id) == hovered_task_id -> "child"
          true -> nil
        end

      (hovered_task[:parent_task_id] || hovered_task.parent_task_id) != nil ->
        parent_id = hovered_task[:parent_task_id] || hovered_task.parent_task_id
        cond do
          task_id == hovered_task_id -> "child"
          task_id == parent_id -> "parent"
          true -> nil
        end

      true ->
        nil
    end
  end
end
