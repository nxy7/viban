defmodule VibanWeb.Live.BoardLive.Components.Column do
  @moduledoc """
  Kanban column component with task cards.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  import VibanWeb.CoreComponents
  import VibanWeb.Live.BoardLive.Components.TaskCard

  use Phoenix.VerifiedRoutes,
    endpoint: VibanWeb.Endpoint,
    router: VibanWeb.Router,
    statics: VibanWeb.static_paths()

  attr :column, :map, required: true
  attr :board_id, :string, required: true
  attr :tasks, :list, required: true
  attr :on_add_click, JS, required: true

  def column(assigns) do
    ~H"""
    <div
      class="flex flex-col bg-gray-900/50 border border-gray-800 rounded-xl min-w-[280px] max-w-[320px] max-h-full"
      id={"column-#{@column.id}"}
      data-column-id={@column.id}
    >
      <div
        class="p-3 border-b border-gray-800 flex items-center justify-between"
        style={"border-left: 3px solid #{@column.color || "#6366f1"}"}
      >
        <div class="flex items-center gap-2">
          <h3 class="font-semibold text-white text-sm">{@column.name}</h3>
          <span class="text-xs text-gray-500 bg-gray-800 px-2 py-0.5 rounded-full">
            {length(@tasks)}
          </span>
        </div>
        <button
          phx-click="show_column_settings"
          phx-value-column_id={@column.id}
          class="text-gray-400 hover:text-white transition-colors"
          title="Column settings"
        >
          <.icon name="hero-cog-6-tooth" class="h-4 w-4" />
        </button>
      </div>

      <div
        class="flex-1 p-3 min-h-0 overflow-y-auto"
        id={"column-tasks-#{@column.id}"}
        data-column-id={@column.id}
        phx-hook="SortableTasks"
      >
        <div class="flex flex-col gap-2">
          <.task_card :for={task <- @tasks} task={task} board_id={@board_id} />

          <div :if={@tasks == []} class="text-center text-gray-500 text-sm py-8">
            No tasks yet
          </div>
        </div>
      </div>

      <div :if={String.upcase(@column.name) == "TODO"} class="p-2 border-t border-gray-800">
        <button
          phx-click={@on_add_click}
          class="w-full flex items-center justify-center gap-2 text-sm text-gray-400 hover:text-white hover:bg-gray-800 py-2 rounded-lg transition-colors"
        >
          <.icon name="hero-plus" class="h-4 w-4" />
          Add a card
        </button>
      </div>
    </div>
    """
  end
end
