defmodule VibanWeb.Hologram.UI.Toast do
  @moduledoc """
  Toast notification component for the Viban design system.

  Displays stackable notifications that auto-dismiss. Timer only decreases on
  the front (first) notification. Notifications grow slightly on hover.

  Usage in page state:
    put_state(component, :toasts, [])

  To show a toast:
    toasts = [%{id: id, message: "Copied!", type: "success"} | component.state.toasts]
    put_state(component, :toasts, toasts)

  In template:
    <ToastContainer toasts={@toasts} />
  """
  use Hologram.Component

  alias VibanWeb.Hologram.UI.Icon

  prop :toasts, :list, default: []
  prop :duration, :integer, default: 3000

  @impl Hologram.Component
  def init(_props, component, server) do
    {component, server}
  end

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="fixed bottom-4 right-4 z-50 flex flex-col-reverse gap-2 pointer-events-none">
      {%for {toast, index} <- Enum.with_index(@toasts)}
        <div
          class={toast_class(toast.type, index)}
          data-toast-id={toast.id}
          data-toast-index={index}
          data-toast-duration={@duration}
        >
          <div class="flex items-center gap-3">
            {%if toast.type == "success"}
              <Icon name="check" size="sm" />
            {/if}
            {%if toast.type == "error"}
              <Icon name="close" size="sm" />
            {/if}
            {%if toast.type == "info"}
              <Icon name="info" size="sm" />
            {/if}
            <span class="text-sm font-medium">{toast.message}</span>
          </div>
          <button
            class="ml-4 p-1 rounded hover:bg-white/10 transition-colors pointer-events-auto"
            data-dismiss-toast={toast.id}
          >
            <Icon name="close" size="xs" />
          </button>
        </div>
      {/for}
    </div>
    """
  end

  defp toast_class(type, index) do
    base = "flex items-center justify-between px-4 py-3 rounded-lg shadow-lg pointer-events-auto transition-all duration-200 hover:scale-105"

    type_class =
      case type do
        "success" -> "bg-green-600 text-white"
        "error" -> "bg-red-600 text-white"
        "warning" -> "bg-yellow-600 text-white"
        "info" -> "bg-brand-600 text-white"
        _ -> "bg-gray-800 text-white border border-gray-700"
      end

    opacity = if index == 0, do: "", else: "opacity-90"

    "#{base} #{type_class} #{opacity}"
  end
end
