defmodule VibanWeb.Live.BoardLive.Components.Modals do
  @moduledoc """
  Modal components for the board view.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  import VibanWeb.CoreComponents

  # ============================================================================
  # Create Task Modal
  # ============================================================================

  attr :form, :any, required: true
  attr :column_id, :string, required: true
  attr :column_name, :string, required: true

  def create_task_modal(assigns) do
    ~H"""
    <.modal id="create-task-modal" show on_cancel={JS.push("hide_create_modal")}>
      <h2 class="text-xl font-semibold mb-4">Create Task in {@column_name}</h2>
      <.form for={@form} phx-submit="create_task" class="space-y-4">
        <input type="hidden" name="column_id" value={@column_id} />
        <.input
          field={@form[:title]}
          label="Title"
          placeholder="Task title..."
          required
          autofocus
        />
        <.input
          field={@form[:description]}
          type="textarea"
          label="Description (optional)"
          placeholder="Describe the task..."
          rows="4"
        />
        <div class="flex justify-end gap-3 pt-2">
          <.button type="button" variant="ghost" phx-click="hide_create_modal">
            Cancel
          </.button>
          <.button type="submit">Create Task</.button>
        </div>
      </.form>
    </.modal>
    """
  end

  # ============================================================================
  # Create PR Modal
  # ============================================================================

  attr :task, :map, required: true
  attr :form, :any, required: true

  def create_pr_modal(assigns) do
    ~H"""
    <.modal id="create-pr-modal" show on_cancel={JS.push("hide_pr_modal")}>
      <h2 class="text-xl font-semibold mb-4">Create Pull Request</h2>
      <.form for={@form} phx-submit="create_pr" class="space-y-4">
        <input type="hidden" name="task_id" value={@task.id} />
        <.input
          field={@form[:title]}
          label="Title"
          placeholder="PR title..."
          value={@task.title}
          required
        />
        <.input
          field={@form[:body]}
          type="textarea"
          label="Description"
          placeholder="Describe the changes..."
          rows="6"
        />
        <.input
          field={@form[:base_branch]}
          label="Base Branch"
          placeholder="main"
          value="main"
        />
        <div class="flex justify-end gap-3 pt-2">
          <.button type="button" variant="ghost" phx-click="hide_pr_modal">
            Cancel
          </.button>
          <.button type="submit">Create PR</.button>
        </div>
      </.form>
    </.modal>
    """
  end

  # ============================================================================
  # Delete Confirm Modal
  # ============================================================================

  def delete_confirm_modal(assigns) do
    ~H"""
    <.modal id="delete-confirm-modal" show on_cancel={JS.push("cancel_delete_task")}>
      <div class="text-center">
        <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-500/20 mb-4">
          <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-400" />
        </div>
        <h2 class="text-xl font-semibold mb-2">Delete Task</h2>
        <p class="text-gray-400 mb-6">Are you sure you want to delete this task? This action cannot be undone.</p>
        <div class="flex justify-center gap-3">
          <.button type="button" variant="ghost" phx-click="cancel_delete_task">
            Cancel
          </.button>
          <.button type="button" variant="danger" phx-click="confirm_delete_task">
            Delete
          </.button>
        </div>
      </div>
    </.modal>
    """
  end

  # ============================================================================
  # Shortcuts Help Modal
  # ============================================================================

  attr :task_open, :boolean, default: false

  def shortcuts_help_modal(assigns) do
    ~H"""
    <.modal id="shortcuts-help-modal" show on_cancel={JS.push("hide_shortcuts_help")}>
      <h2 class="text-xl font-semibold mb-4">Keyboard Shortcuts</h2>
      <div class="space-y-2">
        <.shortcut_row key="Shift + ?" description="Show keyboard shortcuts" />
        <.shortcut_row key="n" description="Create new task" />
        <.shortcut_row key="/" description="Focus search" />
        <.shortcut_row key="," description="Open settings" />

        <div :if={@task_open}>
          <.shortcut_row key="←" description="Previous task" />
          <.shortcut_row key="→" description="Next task" />
          <.shortcut_row key="Backspace" description="Delete task" />
        </div>
      </div>
    </.modal>
    """
  end

  attr :key, :string, required: true
  attr :description, :string, required: true

  defp shortcut_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-2 border-b border-gray-800 last:border-0">
      <span class="text-gray-300">{@description}</span>
      <kbd class="px-2 py-1 text-sm font-mono bg-gray-800 border border-gray-700 rounded text-gray-200">
        {@key}
      </kbd>
    </div>
    """
  end
end
