defmodule VibanWeb.Hologram.UI.Badge do
  @moduledoc """
  Badge/tag component for the Viban design system.

  Variants:
    - default: Gray badge
    - success: Green badge
    - warning: Yellow badge
    - error: Red badge
    - info: Blue badge
    - purple: Purple badge

  Usage:
    <Badge>Default</Badge>
    <Badge variant="success">Active</Badge>
    <Badge variant="error" size="sm">Error</Badge>
  """
  use Hologram.Component

  prop :variant, :string, default: "default"
  prop :size, :string, default: "md"

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <span class={badge_class(@variant, @size)}>
      <slot />
    </span>
    """
  end

  defp badge_class(variant, size) do
    size_class =
      case size do
        "sm" -> "text-xs px-1.5 py-0.5"
        "md" -> "text-xs px-2 py-1"
        "lg" -> "text-sm px-2.5 py-1"
        _ -> "text-xs px-2 py-1"
      end

    variant_class =
      case variant do
        "default" -> "text-gray-400 bg-gray-700"
        "success" -> "text-green-400 bg-green-900/50"
        "warning" -> "text-yellow-400 bg-yellow-900/50"
        "error" -> "text-red-400 bg-red-900/50"
        "info" -> "text-blue-400 bg-blue-900/50"
        "purple" -> "text-purple-400 bg-purple-900/50"
        "brand" -> "text-brand-400 bg-brand-900/50"
        _ -> "text-gray-400 bg-gray-700"
      end

    "inline-flex items-center gap-1 rounded #{size_class} #{variant_class}"
  end
end
