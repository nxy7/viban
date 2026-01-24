defmodule VibanWeb.Hologram.Components.TaskCard do
  use Hologram.Component

  prop :task, :map, required: true
  prop :glow_state, :string, default: nil
  prop :all_tasks, :list, default: []

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div
      class={task_card_class(@glow_state, @task)}
      style={glow_style(@glow_state, @task)}
      data-task-card
      data-task-id={@task.id}
      $click={:open_task_details, task_id: @task.id}
    >
      <div class="flex items-start justify-between gap-2">
        <div class="flex-shrink-0 cursor-grab active:cursor-grabbing text-gray-500 hover:text-gray-300 mr-1 -ml-1" data-drag-handle>
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
            <circle cx="9" cy="6" r="1.5" />
            <circle cx="15" cy="6" r="1.5" />
            <circle cx="9" cy="12" r="1.5" />
            <circle cx="15" cy="12" r="1.5" />
            <circle cx="9" cy="18" r="1.5" />
            <circle cx="15" cy="18" r="1.5" />
          </svg>
        </div>
        <h4 class="text-sm font-medium text-white line-clamp-2 flex-1">{@task.title}</h4>
        {%if @task.in_progress}
          <div class="flex-shrink-0">
            <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
          </div>
        {/if}
        {%if @task.queued_at}
          <span class="flex-shrink-0 text-xs text-yellow-400 bg-yellow-900/50 px-1.5 py-0.5 rounded">
            Queued
          </span>
        {/if}
      </div>

      {%if @task.description}
        <p class="mt-1 text-xs text-gray-400 line-clamp-2">{truncate_description(@task.description)}</p>
      {/if}

      <div class="mt-2 flex items-center gap-2 flex-wrap">
        {%if @task.agent_status != :idle && @task.agent_status}
          <span class={agent_status_class(@task.agent_status)}>
            {%if @task.agent_status == :thinking}
              <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            {/if}
            {agent_status_text(@task.agent_status)}
          </span>
        {/if}

        {%if @task.pr_url}
          <span class={pr_status_class(@task.pr_status)}>
            PR #{@task.pr_number}
          </span>
        {/if}

        {%if @task.error_message}
          <span class="text-xs text-red-400 bg-red-900/50 px-1.5 py-0.5 rounded">
            Error
          </span>
        {/if}

        {%if @task.is_parent}
          <span class="text-xs text-purple-400">
            <svg class="w-3 h-3 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
            </svg>
          </span>
        {/if}

        {%if @task.parent_task_id}
          <span class="text-xs text-blue-400">
            <svg class="w-3 h-3 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6" />
            </svg>
          </span>
        {/if}
      </div>
    </div>
    """
  end

  defp truncate_description(nil), do: ""
  defp truncate_description(desc), do: desc

  defp agent_status_class(:thinking), do: "inline-flex items-center gap-1 text-xs text-blue-400 bg-blue-900/50 px-1.5 py-0.5 rounded"
  defp agent_status_class(:executing), do: "inline-flex items-center gap-1 text-xs text-green-400 bg-green-900/50 px-1.5 py-0.5 rounded"
  defp agent_status_class(:error), do: "inline-flex items-center gap-1 text-xs text-red-400 bg-red-900/50 px-1.5 py-0.5 rounded"
  defp agent_status_class(_), do: "hidden"

  defp agent_status_text(:thinking), do: "Thinking"
  defp agent_status_text(:executing), do: "Executing"
  defp agent_status_text(:error), do: "Error"
  defp agent_status_text(_), do: ""

  defp pr_status_class(:open), do: "text-xs text-green-400 bg-green-900/50 px-1.5 py-0.5 rounded"
  defp pr_status_class(:merged), do: "text-xs text-purple-400 bg-purple-900/50 px-1.5 py-0.5 rounded"
  defp pr_status_class(:closed), do: "text-xs text-red-400 bg-red-900/50 px-1.5 py-0.5 rounded"
  defp pr_status_class(:draft), do: "text-xs text-gray-400 bg-gray-700 px-1.5 py-0.5 rounded"
  defp pr_status_class(_), do: "text-xs text-gray-400 bg-gray-700 px-1.5 py-0.5 rounded"

  defp task_card_class(glow_state, task) do
    base = "block p-3 bg-gray-800 hover:bg-gray-750 rounded-lg transition-all cursor-pointer group"

    border_class =
      cond do
        glow_state == "parent" -> "border-2 border-purple-500"
        glow_state == "child" -> "border-2 border-blue-500"
        task[:agent_status] == :error || task[:agent_status] == "error" -> "border border-red-500/50"
        task[:in_progress] -> "border border-brand-500/50"
        task[:queued_at] -> "border border-yellow-500/30"
        true -> "border border-gray-700 hover:border-gray-600"
      end

    base <> " " <> border_class
  end

  defp glow_style(glow_state, task) do
    cond do
      glow_state == "parent" ->
        "box-shadow: 0 0 20px rgba(147, 51, 234, 0.4), 0 0 40px rgba(147, 51, 234, 0.2)"
      glow_state == "child" ->
        "box-shadow: 0 0 15px rgba(59, 130, 246, 0.3), 0 0 30px rgba(59, 130, 246, 0.15)"
      task[:agent_status] == :error || task[:agent_status] == "error" ->
        "box-shadow: 0 0 15px rgba(239, 68, 68, 0.3)"
      task[:in_progress] ->
        "box-shadow: 0 0 15px rgba(99, 102, 241, 0.3)"
      true ->
        ""
    end
  end
end
