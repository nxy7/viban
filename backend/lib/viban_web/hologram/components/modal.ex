defmodule VibanWeb.Hologram.Components.Modal do
  use Hologram.Component

  prop :is_open, :boolean, default: false
  prop :title, :string, default: ""

  @impl Hologram.Component
  def template do
    ~HOLO"""
    {%if @is_open}
      <div class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="fixed inset-0 bg-black/60 transition-opacity" $click="close_modal"></div>
          <div class="relative transform overflow-hidden rounded-xl bg-gray-900 border border-gray-800 shadow-xl transition-all w-full max-w-lg">
            <div class="flex items-center justify-between p-4 border-b border-gray-800">
              <h3 class="text-lg font-semibold text-white">{@title}</h3>
              <button
                type="button"
                class="text-gray-400 hover:text-white transition-colors"
                $click="close_modal"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div class="p-4">
              <slot />
            </div>
          </div>
        </div>
      </div>
    {/if}
    """
  end

  def action(:close_modal, _params, component) do
    component
  end
end
