defmodule VibanWeb.Hologram.Components.UserMenu do
  use Hologram.Component

  alias VibanWeb.Hologram.UI.{Avatar, Icon}

  prop :user, :map, required: true
  prop :menu_open, :boolean, default: false
  prop :on_toggle, :string, required: true
  prop :on_close, :string, required: true
  prop :on_logout, :string, required: true

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="relative">
      <button
        class="flex items-center gap-2 p-1 rounded-lg hover:bg-gray-800 transition-colors"
        $click={@on_toggle}
      >
        <Avatar src={@user.avatar_url} name={display_name(@user)} size="sm" />
        <span class="text-gray-300 text-sm hidden sm:inline">{display_name(@user)}</span>
        <Icon name="chevron-down" size="sm" class="text-gray-400" />
      </button>

      {%if @menu_open}
        <div
          class="fixed inset-0 z-40"
          $click={@on_close}
        ></div>

        <button
          class="hidden"
          data-keyboard-escape="true"
          $click={@on_close}
        ></button>

        <div class="absolute right-0 mt-2 bg-gray-900 border border-gray-800 rounded-lg shadow-xl py-1 z-50 min-w-48">
          <div class="px-4 py-2 border-b border-gray-800">
            <p class="text-sm font-medium text-white">{display_name(@user)}</p>
            <p class="text-xs text-gray-400">{@user.email}</p>
          </div>
          <button
            class="w-full text-left px-4 py-2 text-sm flex items-center gap-2 text-gray-300 hover:bg-gray-800 transition-colors"
            $click={@on_logout}
          >
            <Icon name="logout" size="sm" />
            Sign out
          </button>
        </div>
      {/if}
    </div>
    """
  end

  defp display_name(user) do
    user.name || user.provider_login || "User"
  end
end
