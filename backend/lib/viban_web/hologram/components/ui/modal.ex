defmodule VibanWeb.Hologram.UI.Modal do
  @moduledoc """
  Modal dialog component for the Viban design system.

  Usage:
    <Modal is_open={@show_modal} title="Create Task" on_close="close_modal">
      <p>Modal content here</p>
    </Modal>

    <Modal is_open={@show_modal} title="Confirm" size="sm" on_close="close_modal">
      <ModalFooter>
        <Button variant="ghost" $click="close_modal">Cancel</Button>
        <Button variant="primary" $click="confirm">Confirm</Button>
      </ModalFooter>
    </Modal>
  """
  use Hologram.Component

  alias VibanWeb.Hologram.UI.Icon

  prop :is_open, :boolean, default: false
  prop :title, :string, default: ""
  prop :size, :string, default: "md"
  prop :on_close, :string, default: nil
  prop :close_target, :string, default: "page"
  prop :scrollable, :boolean, default: false

  @impl Hologram.Component
  def template do
    ~HOLO"""
    {%if @is_open}
      <div class="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50">
        <div class={modal_container_class(@size, @scrollable)}>
          <div class="flex items-center justify-between p-4 border-b border-gray-800">
            <h2 class="text-lg font-semibold text-white">{@title}</h2>
            {%if @on_close}
              <button
                class="p-1 text-gray-400 hover:text-white rounded transition-colors"
                data-keyboard-escape="true"
                $click={action: String.to_atom(@on_close), target: @close_target}
              >
                <Icon name="close" size="md" />
              </button>
            {/if}
          </div>

          <div class={content_class(@scrollable)}>
            <slot />
          </div>
        </div>
      </div>
    {/if}
    """
  end

  defp modal_container_class(size, scrollable) do
    base = "bg-gray-900 border border-gray-800 rounded-xl shadow-2xl mx-4"

    size_class =
      case size do
        "xs" -> "w-full max-w-xs"
        "sm" -> "w-full max-w-sm"
        "md" -> "w-full max-w-lg"
        "lg" -> "w-full max-w-2xl"
        "xl" -> "w-full max-w-4xl"
        _ -> "w-full max-w-lg"
      end

    scroll_class = if scrollable, do: "max-h-[90vh] flex flex-col", else: ""

    [base, size_class, scroll_class]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp content_class(scrollable) do
    if scrollable do
      "p-4 overflow-y-auto flex-1"
    else
      "p-4"
    end
  end
end

defmodule VibanWeb.Hologram.UI.ModalFooter do
  @moduledoc """
  Modal footer component with proper spacing for action buttons.

  Usage:
    <ModalFooter>
      <Button variant="ghost">Cancel</Button>
      <Button variant="primary">Save</Button>
    </ModalFooter>
  """
  use Hologram.Component

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="flex items-center justify-end gap-3 pt-4 mt-4 border-t border-gray-800">
      <slot />
    </div>
    """
  end
end
