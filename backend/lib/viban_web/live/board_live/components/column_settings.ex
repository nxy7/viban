defmodule VibanWeb.Live.BoardLive.Components.ColumnSettings do
  @moduledoc """
  Column settings modal component.
  Provides tabs for General settings (name, color, description), Hooks, and Limits.
  """

  use Phoenix.Component

  import VibanWeb.CoreComponents

  @system_columns ["TODO", "In Progress", "To Review", "Done", "Cancelled"]

  @column_colors [
    {"#6366f1", "Indigo"},
    {"#8b5cf6", "Purple"},
    {"#ec4899", "Pink"},
    {"#ef4444", "Red"},
    {"#f97316", "Orange"},
    {"#eab308", "Yellow"},
    {"#22c55e", "Green"},
    {"#06b6d4", "Cyan"},
    {"#3b82f6", "Blue"},
    {"#64748b", "Slate"}
  ]

  # ============================================================================
  # Column Settings Modal
  # ============================================================================

  attr :show, :boolean, required: true
  attr :column, :map, required: true
  attr :active_tab, :atom, default: :general
  attr :form, :any, default: nil
  attr :show_delete_confirm, :boolean, default: false
  attr :column_hooks, :list, default: []
  attr :available_hooks, :list, default: []
  attr :all_hooks, :list, default: []
  attr :all_system_hooks, :list, default: []

  def column_settings_modal(assigns) do
    assigns =
      assigns
      |> assign(:is_system_column, assigns.column && assigns.column.name in @system_columns)
      |> assign(:is_in_progress, assigns.column && assigns.column.name == "In Progress")
      |> assign(:column_colors, @column_colors)

    ~H"""
    <div
      :if={@show && @column}
      class="fixed inset-0 z-50 flex items-start justify-center pt-20 bg-black/50 backdrop-blur-sm"
      phx-click="hide_column_settings"
    >
      <div
        class="bg-gray-800 border border-gray-700 rounded-lg shadow-xl w-80 max-h-[80vh] flex flex-col animate-slide-in-right"
        phx-click-away="hide_column_settings"
        phx-window-keydown="hide_column_settings"
        phx-key="Escape"
      >
        <div class="flex items-center justify-between px-4 py-3 border-b border-gray-700">
          <h3 class="font-semibold text-white">{@column.name} Settings</h3>
          <button
            phx-click="hide_column_settings"
            class="p-1 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>

        <div class="flex border-b border-gray-700">
          <button
            phx-click="column_settings_tab"
            phx-value-tab="general"
            class="flex-1 px-3 py-2 text-sm font-medium transition-colors"
          >
            <span class={[
              "border-b-2 pb-1",
              @active_tab == :general && "text-white border-brand-500",
              @active_tab != :general && "text-gray-400 border-transparent"
            ]}>
              General
            </span>
          </button>
          <button
            phx-click="column_settings_tab"
            phx-value-tab="hooks"
            class="flex-1 px-3 py-2 text-sm font-medium transition-colors"
          >
            <span class={[
              "border-b-2 pb-1",
              @active_tab == :hooks && "text-white border-brand-500",
              @active_tab != :hooks && "text-gray-400 border-transparent"
            ]}>
              Hooks
            </span>
          </button>
          <button
            :if={@is_in_progress}
            phx-click="column_settings_tab"
            phx-value-tab="limits"
            class="flex-1 px-3 py-2 text-sm font-medium transition-colors"
          >
            <span class={[
              "border-b-2 pb-1",
              @active_tab == :limits && "text-white border-brand-500",
              @active_tab != :limits && "text-gray-400 border-transparent"
            ]}>
              Limits
            </span>
          </button>
        </div>

        <div class="p-4 overflow-y-auto flex-1">
          <.general_tab
            :if={@active_tab == :general}
            column={@column}
            form={@form}
            is_system_column={@is_system_column}
            column_colors={@column_colors}
            show_delete_confirm={@show_delete_confirm}
          />
          <.hooks_tab
            :if={@active_tab == :hooks}
            column={@column}
            column_hooks={@column_hooks}
            available_hooks={@available_hooks}
            all_hooks={@all_hooks}
            all_system_hooks={@all_system_hooks}
          />
          <.limits_tab :if={@active_tab == :limits} column={@column} form={@form} />
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # General Tab
  # ============================================================================

  attr :column, :map, required: true
  attr :form, :any, required: true
  attr :is_system_column, :boolean, required: true
  attr :column_colors, :list, required: true
  attr :show_delete_confirm, :boolean, default: false

  defp general_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <.form :if={@form} for={@form} phx-submit="save_column_settings" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-300 mb-1">Name</label>
          <.input field={@form[:name]} disabled={@is_system_column} />
          <p :if={@is_system_column} class="text-xs text-gray-500 mt-1">
            System columns cannot be renamed
          </p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-300 mb-2">Color</label>
          <div class="flex flex-wrap gap-2">
            <button
              :for={{color, _name} <- @column_colors}
              type="button"
              phx-click="select_column_color"
              phx-value-color={color}
              class={[
                "w-6 h-6 rounded-full transition-transform focus:outline-none",
                @form[:color].value == color &&
                  "scale-110 ring-2 ring-white ring-offset-2 ring-offset-gray-800"
              ]}
              style={"background-color: #{color}"}
            />
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-300 mb-1">
            Description (optional)
          </label>
          <.input
            field={@form[:description]}
            type="textarea"
            rows="2"
            placeholder="What should tasks in this column be doing?"
          />
        </div>

        <.button type="submit" class="w-full">
          Save Changes
        </.button>
      </.form>

      <div class="pt-4 mt-4 border-t border-gray-700">
        <h4 class="text-sm font-medium text-red-400 mb-2">Danger Zone</h4>
        <div :if={!@show_delete_confirm}>
          <.button type="button" variant="danger" phx-click="show_delete_column_tasks" class="w-full">
            Delete All Tasks
          </.button>
        </div>
        <div
          :if={@show_delete_confirm}
          class="p-3 bg-red-900/20 border border-red-500/30 rounded-md space-y-2"
        >
          <p class="text-sm text-red-400">
            Delete all tasks in this column? This cannot be undone.
          </p>
          <div class="flex gap-2">
            <.button
              type="button"
              variant="ghost"
              phx-click="cancel_delete_column_tasks"
              class="flex-1"
            >
              Cancel
            </.button>
            <.button
              type="button"
              variant="danger"
              phx-click="confirm_delete_column_tasks"
              class="flex-1"
            >
              Delete All
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Hooks Tab
  # ============================================================================

  attr :column, :map, required: true
  attr :column_hooks, :list, default: []
  attr :available_hooks, :list, default: []
  attr :all_hooks, :list, default: []
  attr :all_system_hooks, :list, default: []

  defp hooks_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h4 class="text-sm font-medium text-gray-200">On Entry Hooks</h4>
          <p class="text-xs text-gray-500 mt-0.5">
            Run when tasks enter this column
          </p>
        </div>
      </div>

      <div
        :if={@column_hooks == []}
        class="text-center py-4 text-gray-500 border border-dashed border-gray-700 rounded-lg"
      >
        <.icon name="hero-bolt" class="w-5 h-5 mx-auto mb-1 opacity-50" />
        <p class="text-xs">No hooks assigned</p>
      </div>

      <div :if={@column_hooks != []} class="space-y-2">
        <div
          :for={column_hook <- @column_hooks}
          class="p-2 bg-gray-700/50 border border-gray-600 rounded-lg"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2 flex-1 min-w-0">
              <span class={[
                "px-1 py-0.5 text-xs font-medium rounded shrink-0",
                is_system_hook?(column_hook.hook_id) && "bg-purple-600 text-white",
                !is_system_hook?(column_hook.hook_id) && "bg-gray-600 text-gray-200"
              ]}>
                {if is_system_hook?(column_hook.hook_id), do: "SYS", else: "USR"}
              </span>
              <span class="text-sm text-white truncate">
                {get_hook_name(column_hook.hook_id, @all_hooks, @all_system_hooks)}
              </span>
            </div>
            <div class="flex items-center gap-1 shrink-0">
              <button
                type="button"
                phx-click="toggle_column_hook_execute_once"
                phx-value-id={column_hook.id}
                title={if column_hook.execute_once, do: "Execute once: ON", else: "Execute once: OFF"}
                class={[
                  "w-6 h-6 flex items-center justify-center text-xs font-bold rounded transition-colors",
                  column_hook.execute_once && "bg-brand-600 text-white",
                  !column_hook.execute_once && "bg-gray-600 text-gray-400 hover:bg-gray-500"
                ]}
              >
                1x
              </button>
              <button
                type="button"
                phx-click="toggle_column_hook_transparent"
                phx-value-id={column_hook.id}
                title={if column_hook.transparent, do: "Transparent: ON", else: "Transparent: OFF"}
                class={[
                  "w-6 h-6 flex items-center justify-center text-xs font-bold rounded transition-colors",
                  column_hook.transparent && "bg-blue-600 text-white",
                  !column_hook.transparent && "bg-gray-600 text-gray-400 hover:bg-gray-500"
                ]}
              >
                T
              </button>
              <button
                :if={column_hook.removable}
                type="button"
                phx-click="remove_column_hook"
                phx-value-id={column_hook.id}
                class="w-6 h-6 flex items-center justify-center text-gray-400 hover:text-red-400 hover:bg-gray-600 rounded transition-colors"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <div :if={@available_hooks != []} class="pt-2 border-t border-gray-700">
        <label class="block text-xs font-medium text-gray-400 mb-2">Add Hook</label>
        <div class="flex flex-wrap gap-1">
          <button
            :for={hook <- @available_hooks}
            type="button"
            phx-click="add_column_hook"
            phx-value-hook_id={hook.id}
            class={[
              "px-2 py-1 text-xs font-medium rounded transition-colors",
              hook.is_system &&
                "bg-purple-900/50 text-purple-300 hover:bg-purple-900/70 border border-purple-500/30",
              !hook.is_system && "bg-gray-700 text-gray-300 hover:bg-gray-600 border border-gray-600"
            ]}
          >
            + {hook.name}
          </button>
        </div>
      </div>

      <div :if={@available_hooks == [] && @column_hooks != []} class="pt-2 border-t border-gray-700">
        <p class="text-xs text-gray-500 text-center">All hooks assigned</p>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Limits Tab (only for "In Progress" column)
  # ============================================================================

  attr :column, :map, required: true
  attr :form, :any, required: true

  defp limits_tab(assigns) do
    max_concurrent = get_in(assigns.column.settings || %{}, ["max_concurrent_tasks"])
    assigns = assign(assigns, :has_limit, max_concurrent != nil)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h4 class="text-sm font-medium text-gray-200">Limit Concurrent Tasks</h4>
          <p class="text-xs text-gray-500 mt-0.5">
            Control how many tasks can run at once
          </p>
        </div>
        <label class="relative inline-flex items-center cursor-pointer">
          <input
            type="checkbox"
            checked={@has_limit}
            phx-click="toggle_concurrency_limit"
            class="sr-only peer"
          />
          <div class="w-9 h-5 bg-gray-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-brand-600">
          </div>
        </label>
      </div>

      <div :if={@has_limit && @form} class="space-y-4 pl-3 border-l-2 border-brand-500/30">
        <div>
          <label class="block text-sm font-medium text-gray-300 mb-2">
            Maximum Concurrent Tasks
          </label>
          <div class="flex items-center gap-3">
            <.input
              field={@form[:max_concurrent_tasks]}
              type="number"
              min="1"
              max="100"
              class="w-20 text-center"
            />
            <span class="text-sm text-gray-400">tasks at once</span>
          </div>
        </div>

        <.button type="button" phx-click="save_concurrency_limit" class="w-full">
          Save Limit
        </.button>
      </div>

      <div class="p-3 bg-blue-900/20 border border-blue-500/30 rounded-lg">
        <p class="text-xs text-blue-300">
          <.icon name="hero-information-circle" class="w-4 h-4 inline mr-1" />
          When the limit is reached, new tasks will queue and start automatically
          when a slot becomes available.
        </p>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp is_system_hook?(hook_id) when is_binary(hook_id) do
    String.starts_with?(hook_id, "system:")
  end

  defp is_system_hook?(_), do: false

  defp get_hook_name(hook_id, custom_hooks, system_hooks) do
    if is_system_hook?(hook_id) do
      case Enum.find(system_hooks, &(&1.id == hook_id)) do
        nil -> hook_id
        hook -> hook.name
      end
    else
      case Enum.find(custom_hooks, &(&1.id == hook_id)) do
        nil -> "Unknown Hook"
        hook -> hook.name
      end
    end
  end
end
