defmodule VibanWeb.Hologram.UI.Tooltip do
  @moduledoc """
  Tooltip component for the Viban design system.

  Shows a tooltip on hover with customizable position.

  Usage:
    <Tooltip text="Click to copy">
      <button>Copy</button>
    </Tooltip>

    <Tooltip text="Settings" position="bottom">
      <Icon name="settings" />
    </Tooltip>
  """
  use Hologram.Component

  prop :text, :string, required: true
  prop :position, :string, default: "top"

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="relative inline-block group">
      <slot />
      <div class={tooltip_class(@position)}>
        <span class="whitespace-nowrap">{@text}</span>
        <div class={arrow_class(@position)}></div>
      </div>
    </div>
    """
  end

  defp tooltip_class(position) do
    base = "absolute z-50 px-2 py-1 text-xs font-medium text-white bg-gray-900 rounded shadow-lg opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 pointer-events-none"

    position_class =
      case position do
        "top" -> "bottom-full left-1/2 -translate-x-1/2 mb-2"
        "bottom" -> "top-full left-1/2 -translate-x-1/2 mt-2"
        "left" -> "right-full top-1/2 -translate-y-1/2 mr-2"
        "right" -> "left-full top-1/2 -translate-y-1/2 ml-2"
        _ -> "bottom-full left-1/2 -translate-x-1/2 mb-2"
      end

    "#{base} #{position_class}"
  end

  defp arrow_class(position) do
    base = "absolute w-2 h-2 bg-gray-900 transform rotate-45"

    position_class =
      case position do
        "top" -> "top-full left-1/2 -translate-x-1/2 -mt-1"
        "bottom" -> "bottom-full left-1/2 -translate-x-1/2 -mb-1"
        "left" -> "left-full top-1/2 -translate-y-1/2 -ml-1"
        "right" -> "right-full top-1/2 -translate-y-1/2 -mr-1"
        _ -> "top-full left-1/2 -translate-x-1/2 -mt-1"
      end

    "#{base} #{position_class}"
  end
end
