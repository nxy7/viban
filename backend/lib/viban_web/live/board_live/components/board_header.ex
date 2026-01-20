defmodule VibanWeb.Live.BoardLive.Components.BoardHeader do
  @moduledoc """
  Board header component with search, new task button, and settings.
  """

  use Phoenix.Component

  import VibanWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: VibanWeb.Endpoint,
    router: VibanWeb.Router,
    statics: VibanWeb.static_paths()

  attr :board, :map, required: true
  attr :filter_text, :string, required: true
  attr :columns, :list, required: true

  def board_header(assigns) do
    ~H"""
    <header class="flex-shrink-0 bg-gray-900/50 border-b border-gray-800 px-6 py-4">
      <div class="flex items-center justify-between w-full gap-4">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/"} class="text-brand-500 hover:text-brand-400 transition-colors">
            <.icon name="hero-arrow-left" class="h-5 w-5" />
          </.link>
          <div>
            <h1 class="text-xl font-bold text-white">{@board.name}</h1>
            <p :if={@board.description} class="text-sm text-gray-400">{@board.description}</p>
          </div>
        </div>

        <div class="flex-1 max-w-md">
          <div class="relative">
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500"
            />
            <input
              type="text"
              name="filter"
              id="search-input"
              value={@filter_text}
              placeholder="Filter tasks..."
              phx-keyup="filter"
              phx-debounce="150"
              phx-hook="FocusSearch"
              class="w-full rounded-lg border border-gray-700 bg-gray-800 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent transition-colors pl-10 pr-3 py-1.5 text-sm"
            />
          </div>
        </div>

        <div class="flex items-center gap-2">
          <.button phx-click="show_create_modal" phx-value-column_id={first_todo_column_id(@columns)}>
            <.icon name="hero-plus" class="h-4 w-4" /> New Task
          </.button>
          <.button variant="secondary" phx-click="show_settings">
            <.icon name="hero-cog-6-tooth" class="h-4 w-4" /> Settings
          </.button>
          <button
            phx-click="shortcut_help"
            class="w-8 h-8 flex items-center justify-center text-gray-400 hover:text-brand-400 active:text-brand-500 transition-colors"
            title="Keyboard shortcuts (Shift+?)"
          >
            <.icon name="hero-question-mark-circle" class="h-5 w-5" />
          </button>
        </div>
      </div>
    </header>
    """
  end

  defp first_todo_column_id(columns) do
    case Enum.find(columns, fn c -> String.upcase(c.name) == "TODO" end) do
      nil -> nil
      column -> column.id
    end
  end
end
