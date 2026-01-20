defmodule VibanWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for the LiveView application.

  These components are designed to match the SolidJS frontend styling
  for a consistent look across both versions.
  """
  use Phoenix.Component
  use Gettext, backend: VibanWeb.Gettext

  alias Phoenix.HTML.FormField
  alias Phoenix.LiveView.JS

  # ============================================================================
  # Flash Components
  # ============================================================================

  attr :flash, :map, required: true
  attr :kind, :atom, values: [:info, :error, :warning, :success], default: :info

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={"flash-#{@kind}"}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("#flash-#{@kind}")}
      phx-mounted={
        JS.transition(
          {"ease-out duration-300", "translate-x-full opacity-0", "translate-x-0 opacity-100"}
        )
      }
      phx-remove={
        JS.transition(
          {"ease-in duration-200", "translate-x-0 opacity-100", "translate-x-full opacity-0"}
        )
      }
      role="alert"
      class={[
        "fixed top-4 right-4 z-50 w-80 rounded-lg border shadow-lg backdrop-blur-sm overflow-hidden cursor-pointer",
        flash_bg_classes(@kind)
      ]}
    >
      <div class="flex items-start gap-3 p-4">
        <div class="flex-shrink-0 mt-0.5">
          <.icon
            :if={@kind == :info}
            name="hero-information-circle"
            class={["h-5 w-5", flash_icon_classes(@kind)]}
          />
          <.icon
            :if={@kind == :success}
            name="hero-check-circle"
            class={["h-5 w-5", flash_icon_classes(@kind)]}
          />
          <.icon
            :if={@kind == :error}
            name="hero-exclamation-circle"
            class={["h-5 w-5", flash_icon_classes(@kind)]}
          />
          <.icon
            :if={@kind == :warning}
            name="hero-exclamation-triangle"
            class={["h-5 w-5", flash_icon_classes(@kind)]}
          />
        </div>
        <div class="flex-1 min-w-0">
          <p class={["text-sm font-medium", flash_title_classes(@kind)]}>
            {msg}
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp flash_bg_classes(:success), do: "bg-green-900/95 border-green-500/50"
  defp flash_bg_classes(:error), do: "bg-red-900/95 border-red-500/50"
  defp flash_bg_classes(:warning), do: "bg-amber-900/95 border-amber-500/50"
  defp flash_bg_classes(:info), do: "bg-blue-900/95 border-blue-500/50"

  defp flash_icon_classes(:success), do: "text-green-400"
  defp flash_icon_classes(:error), do: "text-red-400"
  defp flash_icon_classes(:warning), do: "text-amber-400"
  defp flash_icon_classes(:info), do: "text-blue-400"

  defp flash_title_classes(:success), do: "text-green-300"
  defp flash_title_classes(:error), do: "text-red-300"
  defp flash_title_classes(:warning), do: "text-amber-300"
  defp flash_title_classes(:info), do: "text-blue-300"

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:success} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.flash kind={:warning} flash={@flash} />
    </div>
    """
  end

  # ============================================================================
  # Button Components
  # ============================================================================

  attr :type, :string, default: nil
  attr :variant, :string, default: "primary", values: ["primary", "secondary", "danger", "ghost"]
  attr :size, :string, default: "md", values: ["sm", "md", "lg"]
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :rest, :global, include: ~w(form name value phx-click phx-disable-with)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled || @loading}
      class={[
        "inline-flex items-center justify-center gap-2 font-medium transition-colors rounded-lg",
        "focus:outline-none focus:ring-2 focus:ring-brand-500 focus:ring-offset-2 focus:ring-offset-gray-950",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        variant_classes(@variant),
        size_classes(@size),
        @class
      ]}
      {@rest}
    >
      <.spinner :if={@loading} class="h-4 w-4" />
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp variant_classes("primary"), do: "bg-brand-600 hover:bg-brand-700 text-white"
  defp variant_classes("secondary"), do: "bg-gray-800 hover:bg-gray-700 text-white border border-gray-700"
  defp variant_classes("danger"), do: "bg-red-600 hover:bg-red-700 text-white"
  defp variant_classes("ghost"), do: "hover:bg-gray-800 text-gray-300"

  defp size_classes("sm"), do: "px-2.5 py-1.5 text-xs"
  defp size_classes("md"), do: "px-4 py-2 text-sm"
  defp size_classes("lg"), do: "px-6 py-3 text-base"

  # ============================================================================
  # Input Components
  # ============================================================================

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, FormField, doc: "a form field struct"
  attr :errors, :list, default: []
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                                   multiple pattern placeholder readonly required rows size step autofocus)

  def input(%{field: %FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, errors)
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <label :if={@label} for={@id} class="block text-sm font-medium text-gray-300 mb-1">
        {@label}
      </label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "w-full rounded-lg border border-gray-700 bg-gray-900 text-white placeholder-gray-500",
          "focus:border-brand-500 focus:ring-1 focus:ring-brand-500 focus:outline-none",
          "resize-none",
          @errors != [] && "border-red-500",
          @class
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <label :if={@label} for={@id} class="block text-sm font-medium text-gray-300 mb-1">
        {@label}
      </label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "w-full rounded-lg border border-gray-700 bg-gray-900 text-white placeholder-gray-500",
          "focus:border-brand-500 focus:ring-1 focus:ring-brand-500 focus:outline-none",
          "px-3 py-2 text-sm",
          @errors != [] && "border-red-500",
          @class
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def error(assigns) do
    ~H"""
    <p class="mt-1 flex gap-1 text-sm text-red-400">
      <.icon name="hero-exclamation-circle-mini" class="h-4 w-4 mt-0.5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  # ============================================================================
  # Modal Components (Native <dialog>)
  # ============================================================================

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}

  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <dialog
      id={@id}
      data-cancel={@on_cancel}
      data-show={to_string(@show)}
      phx-hook="Dialog"
      class="backdrop:bg-black/80 bg-transparent p-0 max-w-lg w-full open:flex open:items-center open:justify-center"
    >
      <div class="relative w-full rounded-xl bg-gray-900 border border-gray-800 shadow-xl p-6">
        <button
          phx-click={@on_cancel}
          type="button"
          class="absolute top-4 right-4 text-gray-400 hover:text-white"
          aria-label="close"
        >
          <.icon name="hero-x-mark-solid" class="h-5 w-5" />
        </button>
        {render_slot(@inner_block)}
      </div>
    </dialog>
    """
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    JS.dispatch(js, "phx:show-modal", to: "##{id}")
  end

  def hide_modal(js \\ %JS{}, id) do
    JS.dispatch(js, "phx:hide-modal", to: "##{id}")
  end

  # ============================================================================
  # Side Panel Component
  # ============================================================================

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "2xl"]

  slot :inner_block, required: true

  def side_panel(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_panel(@id)}
      phx-remove={hide_panel(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-40 hidden"
    >
      <div id={"#{@id}-bg"} class="fixed inset-0 bg-black/60 transition-opacity" aria-hidden="true" />
      <div class="fixed inset-0 overflow-hidden">
        <div class="absolute inset-0 overflow-hidden">
          <div class="pointer-events-none fixed inset-y-0 right-0 flex max-w-full">
            <div
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              class={[
                "pointer-events-auto relative flex flex-col bg-gray-900 border-l border-gray-800 shadow-xl h-full transition",
                panel_width_class(@width)
              ]}
            >
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp panel_width_class("sm"), do: "w-80"
  defp panel_width_class("md"), do: "w-96"
  defp panel_width_class("lg"), do: "w-[32rem]"
  defp panel_width_class("xl"), do: "w-[40rem]"
  defp panel_width_class("2xl"), do: "w-[48rem]"

  def show_panel(js \\ %JS{}, id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(to: "##{id}-bg", transition: {"ease-out duration-200", "opacity-0", "opacity-100"})
    |> JS.show(to: "##{id}-container", transition: {"ease-out duration-300", "translate-x-full", "translate-x-0"})
    |> JS.add_class("overflow-hidden", to: "body")
  end

  def hide_panel(js \\ %JS{}, id) do
    js
    |> JS.hide(to: "##{id}-bg", transition: {"ease-in duration-200", "opacity-100", "opacity-0"})
    |> JS.hide(to: "##{id}-container", transition: {"ease-in duration-200", "translate-x-0", "translate-x-full"})
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
  end

  # ============================================================================
  # Icon Components
  # ============================================================================

  attr :name, :string, required: true
  attr :class, :any, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def spinner(assigns) do
    ~H"""
    <svg
      class={["animate-spin", @class]}
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
      </circle>
      <path
        class="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      >
      </path>
    </svg>
    """
  end

  # ============================================================================
  # Badge Components
  # ============================================================================

  attr :color, :string, default: "gray", values: ["gray", "brand", "red", "yellow", "green", "blue", "purple"]
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium",
      badge_color_class(@color),
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp badge_color_class("gray"), do: "bg-gray-800 text-gray-300"
  defp badge_color_class("brand"), do: "bg-brand-900 text-brand-300"
  defp badge_color_class("red"), do: "bg-red-900 text-red-300"
  defp badge_color_class("yellow"), do: "bg-yellow-900 text-yellow-300"
  defp badge_color_class("green"), do: "bg-green-900 text-green-300"
  defp badge_color_class("blue"), do: "bg-blue-900 text-blue-300"
  defp badge_color_class("purple"), do: "bg-purple-900 text-purple-300"

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp hide(js, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0 translate-y-1"}
    )
  end
end
