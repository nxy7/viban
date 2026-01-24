defmodule VibanWeb.Hologram.UI.Dropdown do
  @moduledoc """
  Dropdown menu component for the Viban design system.

  Usage:
    <Dropdown is_open={@menu_open}>
      <DropdownItem $click="edit">Edit</DropdownItem>
      <DropdownDivider />
      <DropdownItem $click="delete" variant="danger">Delete</DropdownItem>
    </Dropdown>
  """
  use Hologram.Component

  prop :is_open, :boolean, default: false
  prop :position, :string, default: "right"

  @impl Hologram.Component
  def template do
    ~HOLO"""
    {%if @is_open}
      <div class={dropdown_class(@position)}>
        <slot />
      </div>
    {/if}
    """
  end

  defp dropdown_class(position) do
    base = "absolute mt-2 bg-gray-900 border border-gray-800 rounded-lg shadow-xl py-1 z-50 min-w-48"

    position_class =
      case position do
        "left" -> "left-0"
        "right" -> "right-0"
        "center" -> "left-1/2 -translate-x-1/2"
        _ -> "right-0"
      end

    "#{base} #{position_class}"
  end
end

defmodule VibanWeb.Hologram.UI.DropdownItem do
  @moduledoc """
  Dropdown menu item component.

  Usage:
    <DropdownItem $click="edit">Edit</DropdownItem>
    <DropdownItem variant="danger" $click="delete">Delete</DropdownItem>
  """
  use Hologram.Component

  alias VibanWeb.Hologram.UI.Icon

  prop :icon, :string, default: nil
  prop :variant, :string, default: "default"

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <button class={item_class(@variant)}>
      {%if @icon}
        <Icon name={@icon} size="sm" />
      {/if}
      <slot />
    </button>
    """
  end

  defp item_class(variant) do
    base = "w-full text-left px-4 py-2 text-sm flex items-center gap-2 transition-colors"

    variant_class =
      case variant do
        "danger" -> "text-red-400 hover:bg-red-900/30"
        _ -> "text-gray-300 hover:bg-gray-800"
      end

    "#{base} #{variant_class}"
  end
end

defmodule VibanWeb.Hologram.UI.DropdownDivider do
  @moduledoc """
  Dropdown menu divider.

  Usage:
    <DropdownDivider />
  """
  use Hologram.Component

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="border-t border-gray-800 my-1"></div>
    """
  end
end

defmodule VibanWeb.Hologram.UI.DropdownHeader do
  @moduledoc """
  Dropdown menu header section.

  Usage:
    <DropdownHeader>
      <p class="font-medium">User Name</p>
      <p class="text-xs text-gray-400">email@example.com</p>
    </DropdownHeader>
  """
  use Hologram.Component

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="px-4 py-2 border-b border-gray-800">
      <slot />
    </div>
    """
  end
end
