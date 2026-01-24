defmodule VibanWeb.Hologram.UI.Input do
  @moduledoc """
  Input component for the Viban design system.

  Usage:
    <Input placeholder="Enter name..." value={@name} $input="update_name" />
    <Input type="textarea" rows="3" placeholder="Description..." />
    <Input label="Email" type="email" required={true} />
  """
  use Hologram.Component

  prop :type, :string, default: "text"
  prop :value, :string, default: ""
  prop :placeholder, :string, default: ""
  prop :label, :string, default: nil
  prop :rows, :integer, default: 3
  prop :disabled, :boolean, default: false
  prop :required, :boolean, default: false
  prop :error, :string, default: nil

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="w-full">
      {%if @label}
        <label class="block text-sm font-medium text-gray-300 mb-2">
          {@label}
          {%if @required}
            <span class="text-red-400">*</span>
          {/if}
        </label>
      {/if}

      {%if @type == "textarea"}
        <textarea
          placeholder={@placeholder}
          class={input_class(@error, @disabled)}
          rows={@rows}
          disabled={@disabled}
        >{@value}</textarea>
      {%else}
        <input
          type={@type}
          placeholder={@placeholder}
          value={@value}
          class={input_class(@error, @disabled)}
          disabled={@disabled}
        />
      {/if}

      {%if @error}
        <p class="mt-1 text-sm text-red-400">{@error}</p>
      {/if}
    </div>
    """
  end

  defp input_class(error, disabled) do
    base = "w-full bg-gray-800 border rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none transition-colors"

    border_class =
      cond do
        error -> "border-red-500 focus:border-red-500"
        disabled -> "border-gray-700 opacity-50 cursor-not-allowed"
        true -> "border-gray-700 focus:border-brand-500"
      end

    extra = if disabled, do: "resize-none", else: ""

    [base, border_class, extra]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end
end
