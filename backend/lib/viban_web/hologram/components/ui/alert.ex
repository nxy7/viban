defmodule VibanWeb.Hologram.UI.Alert do
  @moduledoc """
  Alert/notification component for the Viban design system.

  Variants:
    - info: Informational (blue)
    - success: Success message (green)
    - warning: Warning message (yellow)
    - error: Error message (red)

  Usage:
    <Alert variant="error">{@error_message}</Alert>
    <Alert variant="success" dismissible={true}>Saved successfully!</Alert>
  """
  use Hologram.Component

  alias VibanWeb.Hologram.UI.Icon

  prop :variant, :string, default: "info"
  prop :dismissible, :boolean, default: false
  prop :title, :string, default: nil

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class={alert_class(@variant)}>
      <div class="flex items-start gap-3">
        <div class="flex-1">
          {%if @title}
            <h4 class={title_class(@variant)}>{@title}</h4>
          {/if}
          <div class={text_class(@variant)}>
            <slot />
          </div>
        </div>
        {%if @dismissible}
          <button class={dismiss_class(@variant)} $click="dismiss">
            <Icon name="close" size="sm" />
          </button>
        {/if}
      </div>
    </div>
    """
  end

  def action(:dismiss, _params, component) do
    component
  end

  defp alert_class(variant) do
    base = "p-3 rounded-lg border"

    variant_class =
      case variant do
        "info" -> "bg-blue-500/20 border-blue-500/50"
        "success" -> "bg-green-500/20 border-green-500/50"
        "warning" -> "bg-yellow-500/20 border-yellow-500/50"
        "error" -> "bg-red-500/20 border-red-500/50"
        _ -> "bg-blue-500/20 border-blue-500/50"
      end

    "#{base} #{variant_class}"
  end

  defp title_class(variant) do
    base = "font-medium mb-1"

    color =
      case variant do
        "info" -> "text-blue-400"
        "success" -> "text-green-400"
        "warning" -> "text-yellow-400"
        "error" -> "text-red-400"
        _ -> "text-blue-400"
      end

    "#{base} #{color}"
  end

  defp text_class(variant) do
    case variant do
      "info" -> "text-blue-300 text-sm"
      "success" -> "text-green-300 text-sm"
      "warning" -> "text-yellow-300 text-sm"
      "error" -> "text-red-300 text-sm"
      _ -> "text-blue-300 text-sm"
    end
  end

  defp dismiss_class(variant) do
    base = "p-1 rounded transition-colors"

    hover =
      case variant do
        "info" -> "text-blue-400 hover:bg-blue-500/30"
        "success" -> "text-green-400 hover:bg-green-500/30"
        "warning" -> "text-yellow-400 hover:bg-yellow-500/30"
        "error" -> "text-red-400 hover:bg-red-500/30"
        _ -> "text-blue-400 hover:bg-blue-500/30"
      end

    "#{base} #{hover}"
  end
end
