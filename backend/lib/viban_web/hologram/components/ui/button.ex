defmodule VibanWeb.Hologram.UI.Button do
  @moduledoc """
  Button component for the Viban design system.

  Variants:
    - primary: Main action button (brand color)
    - secondary: Secondary action (gray background)
    - ghost: Text-only button
    - danger: Destructive action (red)
    - icon: Icon-only button

  Usage:
    <Button variant="primary">Save</Button>
    <Button variant="secondary" $click="cancel">Cancel</Button>
    <Button variant="icon" $click="close"><Icon name="close" /></Button>
    <Button variant="primary" loading={true}>Saving...</Button>
  """
  use Hologram.Component

  prop :variant, :string, default: "primary"
  prop :size, :string, default: "md"
  prop :disabled, :boolean, default: false
  prop :loading, :boolean, default: false
  prop :full_width, :boolean, default: false
  prop :type, :string, default: "button"

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <button
      type={@type}
      class={button_class(@variant, @size, @disabled, @loading, @full_width)}
      disabled={@disabled || @loading}
    >
      {%if @loading}
        <span class="flex items-center gap-2">
          <div class={spinner_class(@variant)}></div>
          <slot />
        </span>
      {%else}
        <slot />
      {/if}
    </button>
    """
  end

  defp button_class(variant, size, disabled, loading, full_width) do
    base = "inline-flex items-center justify-center font-medium rounded-lg transition-colors"

    variant_class =
      case variant do
        "primary" -> "bg-brand-600 hover:bg-brand-700 text-white"
        "secondary" -> "bg-gray-800 hover:bg-gray-700 text-white border border-gray-700"
        "ghost" -> "text-gray-300 hover:text-white hover:bg-gray-800"
        "danger" -> "bg-red-600 hover:bg-red-700 text-white"
        "icon" -> "p-1 text-gray-400 hover:text-white rounded transition-colors"
        _ -> "bg-brand-600 hover:bg-brand-700 text-white"
      end

    size_class =
      if variant == "icon" do
        case size do
          "sm" -> "p-1"
          "md" -> "p-1.5"
          "lg" -> "p-2"
          _ -> "p-1.5"
        end
      else
        case size do
          "sm" -> "px-3 py-1.5 text-sm gap-1.5"
          "md" -> "px-4 py-2 gap-2"
          "lg" -> "px-6 py-3 text-lg gap-2"
          _ -> "px-4 py-2 gap-2"
        end
      end

    disabled_class =
      if disabled || loading do
        "opacity-50 cursor-not-allowed"
      else
        ""
      end

    width_class = if full_width, do: "w-full", else: ""

    [base, variant_class, size_class, disabled_class, width_class]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp spinner_class(variant) do
    color =
      case variant do
        "primary" -> "border-white/50 border-t-white"
        "secondary" -> "border-gray-600 border-t-white"
        "ghost" -> "border-gray-600 border-t-white"
        "danger" -> "border-white/50 border-t-white"
        _ -> "border-white/50 border-t-white"
      end

    "animate-spin rounded-full h-4 w-4 border #{color}"
  end
end
