defmodule VibanWeb.Live.BoardLive.Components.TaskCard do
  @moduledoc """
  Task card component displayed in columns.
  """

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: VibanWeb.Endpoint,
    router: VibanWeb.Router,
    statics: VibanWeb.static_paths()

  import VibanWeb.CoreComponents

  alias Phoenix.LiveView.JS

  attr :task, :map, required: true
  attr :board_id, :string, required: true

  def task_card(assigns) do
    ~H"""
    <div
      id={"task-#{@task.id}"}
      data-task-id={@task.id}
      phx-click={JS.patch(~p"/board/#{@board_id}/task/#{@task.id}")}
      class={[
        "relative border rounded-md p-3 cursor-pointer bg-gray-800/80",
        "transition-transform duration-150",
        "hover:border-gray-600 hover:bg-gray-800",
        task_border_class(@task)
      ]}
      style={task_glow_style(@task)}
    >
      <div class="flex flex-col gap-2 min-w-0">
        <div class="flex items-start justify-between gap-2 min-w-0">
          <h4 class="text-sm font-medium text-white line-clamp-2 flex-1 min-w-0">
            {@task.title}
          </h4>
          <.task_status_icon task={@task} />
        </div>

        <p :if={@task.description} class="text-xs text-gray-400 line-clamp-3">
          {@task.description}
        </p>

        <.task_badges task={@task} />
      </div>
    </div>
    """
  end

  defp task_status_icon(assigns) do
    ~H"""
    <span :if={@task.in_progress && !@task.queued_at} class="text-brand-400">
      <.spinner class="h-4 w-4" />
    </span>
    <span :if={@task.agent_status == :thinking} class="text-blue-400" title="Waiting for user input">
      <.icon name="hero-chat-bubble-left-ellipsis" class="h-4 w-4" />
    </span>
    <span :if={@task.queued_at} class="text-yellow-400" title="Queued">
      <.icon name="hero-queue-list" class="h-4 w-4" />
    </span>
    """
  end

  defp task_badges(assigns) do
    ~H"""
    <span
      :if={@task.queued_at}
      class="text-xs px-2 py-0.5 rounded-full bg-yellow-500/20 text-yellow-400 border border-yellow-500/30 self-start"
    >
      Queued
    </span>

    <span
      :if={@task.in_progress && !@task.queued_at}
      class="text-xs px-2 py-0.5 rounded-full bg-brand-500/20 text-brand-400 border border-brand-500/30 self-start truncate max-w-full"
    >
      {@task.agent_status_message || "Working..."}
    </span>

    <span
      :if={@task.agent_status == :thinking}
      class="text-xs px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400 border border-blue-500/30 self-start truncate max-w-full"
    >
      {@task.agent_status_message || "Waiting for input"}
    </span>

    <span
      :if={@task.agent_status == :error}
      class="text-xs px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 border border-red-500/30 self-start truncate max-w-full"
      title={@task.error_message || "Error"}
    >
      {String.slice(@task.error_message || "Error", 0, 40)}
    </span>

    <a
      :if={@task.pr_url && @task.pr_status}
      href={@task.pr_url}
      target="_blank"
      rel="noopener noreferrer"
      onclick="event.stopPropagation()"
      class={[
        "text-xs px-2 py-0.5 rounded-full self-start flex items-center gap-1 hover:opacity-80 transition-opacity",
        pr_badge_classes(@task.pr_status)
      ]}
    >
      <.pr_icon />
      <span>{@task.pr_number}</span>
    </a>

    <span
      :if={@task.is_parent}
      class="text-xs px-2 py-0.5 rounded-full bg-purple-500/20 text-purple-400 border border-purple-500/30 self-start flex items-center gap-1"
    >
      <.icon name="hero-folder" class="h-3 w-3" /> Parent
    </span>

    <span
      :if={@task.parent_task_id}
      class="text-xs px-2 py-0.5 rounded-full bg-purple-500/10 text-purple-300 border border-purple-500/20 self-start flex items-center gap-1"
    >
      <.icon name="hero-document" class="h-3 w-3" /> Subtask
    </span>
    """
  end

  defp pr_icon(assigns) do
    assigns = assign(assigns, :class, "h-3 w-3")

    ~H"""
    <svg class={@class} viewBox="0 0 16 16" fill="currentColor">
      <path d="M1.5 3.25a2.25 2.25 0 1 1 3 2.122v5.256a2.251 2.251 0 1 1-1.5 0V5.372A2.25 2.25 0 0 1 1.5 3.25Zm5.677-.177L9.573.677A.25.25 0 0 1 10 .854V2.5h1A2.5 2.5 0 0 1 13.5 5v5.628a2.251 2.251 0 1 1-1.5 0V5a1 1 0 0 0-1-1h-1v1.646a.25.25 0 0 1-.427.177L7.177 3.427a.25.25 0 0 1 0-.354Z" />
    </svg>
    """
  end

  defp pr_badge_classes(:open), do: "bg-green-500/20 text-green-400 border border-green-500/30"
  defp pr_badge_classes(:merged), do: "bg-purple-500/20 text-purple-400 border border-purple-500/30"
  defp pr_badge_classes(:closed), do: "bg-red-500/20 text-red-400 border border-red-500/30"
  defp pr_badge_classes(:draft), do: "bg-gray-500/20 text-gray-400 border border-gray-500/30"
  defp pr_badge_classes(_), do: "bg-gray-500/20 text-gray-400 border border-gray-500/30"

  defp task_border_class(task) do
    cond do
      task.agent_status == :error -> "border-red-500/50"
      task.in_progress -> "border-brand-500/50"
      task.queued_at -> "border-yellow-500/30"
      true -> "border-gray-700"
    end
  end

  defp task_glow_style(task) do
    cond do
      task.agent_status == :error ->
        "box-shadow: 0 0 20px rgba(239, 68, 68, 0.3)"

      task.in_progress ->
        "box-shadow: 0 0 20px rgba(139, 92, 246, 0.3)"

      task.queued_at ->
        "box-shadow: 0 0 15px rgba(234, 179, 8, 0.2)"

      true ->
        ""
    end
  end
end
