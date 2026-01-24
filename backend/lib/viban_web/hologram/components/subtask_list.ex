defmodule VibanWeb.Hologram.Components.SubtaskList do
  use Hologram.Component

  prop :task, :map, required: true
  prop :subtasks, :list, default: []
  prop :is_generating, :boolean, default: false

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="space-y-3">
      <div class="flex items-center justify-between">
        <h4 class="text-sm font-medium text-gray-400 flex items-center gap-2">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
          </svg>
          Subtasks
          {%if length(@subtasks) > 0}
            <span class="text-xs text-gray-500">({length(@subtasks)})</span>
          {/if}
        </h4>

        {%if length(@subtasks) > 0}
          <div class="flex items-center gap-2 text-xs text-gray-500">
            <span>{progress_percentage(@subtasks)}%</span>
            <div class="w-16 h-1.5 bg-gray-700 rounded-full overflow-hidden">
              <div
                class="h-full bg-gradient-to-r from-brand-600 to-brand-400 rounded-full transition-all duration-300"
                style={progress_bar_style(@subtasks)}
              ></div>
            </div>
          </div>
        {/if}
      </div>

      {%if @is_generating || @task.subtask_generation_status == :generating}
        <div class="flex items-center gap-2 p-3 bg-purple-500/10 border border-purple-500/30 rounded-lg">
          <svg class="w-4 h-4 text-purple-400 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="text-sm text-purple-400">AI is breaking down your task into subtasks...</span>
        </div>
      {/if}

      {%if @task.subtask_generation_status == :failed}
        <div class="flex items-center justify-between gap-2 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
          <span class="text-sm text-red-400">
            Failed to generate subtasks.
            {%if @task.agent_status_message}
              {@task.agent_status_message}
            {/if}
          </span>
          <button
            type="button"
            class="px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white text-sm rounded transition-colors"
            $click={action: :generate_subtasks, params: %{task_id: @task.id}, target: "page"}
          >
            Retry
          </button>
        </div>
      {/if}

      {%if length(@subtasks) > 0}
        <div class="space-y-2">
          {%for subtask <- @subtasks}
            <button
              type="button"
              class="w-full flex items-center gap-3 p-3 bg-gray-800 hover:bg-gray-750 border border-gray-700 hover:border-gray-600 rounded-lg transition-colors text-left"
              $click={action: :open_subtask, params: %{subtask_id: subtask.id}, target: "page"}
            >
              <div class={status_indicator_class(subtask.agent_status)}></div>
              <div class="flex-1 min-w-0">
                <div class="font-medium text-white text-sm truncate">{subtask.title}</div>
                {%if subtask.description}
                  <div class="text-xs text-gray-500 truncate mt-0.5">{subtask.description}</div>
                {/if}
              </div>
              {%if subtask.priority}
                <span class={priority_badge_class(subtask.priority)}>{subtask.priority}</span>
              {/if}
              {%if subtask.agent_status == :thinking || subtask.agent_status == :executing}
                <svg class="w-3 h-3 text-blue-400 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              {/if}
              <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          {/for}
        </div>
      {/if}

      {%if length(@subtasks) == 0 && !@is_generating && @task.subtask_generation_status != :generating}
        <div class="text-center py-6 space-y-3">
          <p class="text-sm text-gray-500">No subtasks yet</p>
          <button
            type="button"
            class="inline-flex items-center gap-2 px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white text-sm font-medium rounded-lg transition-colors"
            $click={action: :generate_subtasks, params: %{task_id: @task.id}, target: "page"}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            Generate Subtasks with AI
          </button>
        </div>
      {/if}

      {%if length(@subtasks) > 0 && !@is_generating && @task.subtask_generation_status != :generating}
        <div class="text-center pt-2">
          <button
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 text-purple-400 hover:text-purple-300 hover:bg-purple-900/30 text-sm rounded-lg transition-colors"
            $click={action: :generate_subtasks, params: %{task_id: @task.id}, target: "page"}
          >
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            Generate More
          </button>
        </div>
      {/if}
    </div>
    """
  end

  defp progress_percentage(subtasks) when is_list(subtasks) do
    total = length(subtasks)

    if total == 0 do
      0
    else
      completed = Enum.count(subtasks, fn s -> s.agent_status == :idle end)
      div(completed * 100, total)
    end
  end

  defp progress_bar_style(subtasks) do
    percentage = progress_percentage(subtasks)
    "width: #{percentage}%"
  end

  defp status_indicator_class(:thinking), do: "w-2 h-2 rounded-full flex-shrink-0 bg-blue-500 animate-pulse"
  defp status_indicator_class(:executing), do: "w-2 h-2 rounded-full flex-shrink-0 bg-green-500 animate-pulse"
  defp status_indicator_class(:error), do: "w-2 h-2 rounded-full flex-shrink-0 bg-red-500"
  defp status_indicator_class(_), do: "w-2 h-2 rounded-full flex-shrink-0 bg-gray-600"

  defp priority_badge_class(:high), do: "text-xs px-1.5 py-0.5 rounded bg-red-500/20 text-red-400"
  defp priority_badge_class(:low), do: "text-xs px-1.5 py-0.5 rounded bg-gray-500/20 text-gray-400"
  defp priority_badge_class(_), do: "text-xs px-1.5 py-0.5 rounded bg-blue-500/20 text-blue-400"
end
