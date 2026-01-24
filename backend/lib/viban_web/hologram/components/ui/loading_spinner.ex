defmodule VibanWeb.Hologram.UI.LoadingSpinner do
  @moduledoc """
  SVG-based loading spinner component for the Viban design system.

  Usage:
    <LoadingSpinner />
    <LoadingSpinner size="lg" />
    <LoadingSpinner size="sm" color="white" />
  """
  use Hologram.Component

  prop :size, :string, default: "md"
  prop :color, :string, default: "brand"

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <svg class={svg_class(@size)} viewBox="0 0 24 24" fill="none">
      <circle
        class="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke={stroke_color(@color)}
        stroke-width="4"
      />
      <path
        class="opacity-75"
        fill={stroke_color(@color)}
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      />
    </svg>
    """
  end

  defp svg_class(size) do
    base = "animate-spin"
    size_class =
      case size do
        "xs" -> "h-3 w-3"
        "sm" -> "h-4 w-4"
        "md" -> "h-6 w-6"
        "lg" -> "h-8 w-8"
        "xl" -> "h-10 w-10"
        _ -> "h-6 w-6"
      end
    "#{base} #{size_class}"
  end

  defp stroke_color(color) do
    case color do
      "brand" -> "#3b82f6"
      "white" -> "#ffffff"
      "gray" -> "#9ca3af"
      _ -> "#3b82f6"
    end
  end
end
