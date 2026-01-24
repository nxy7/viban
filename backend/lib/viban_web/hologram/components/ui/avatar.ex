defmodule VibanWeb.Hologram.UI.Avatar do
  @moduledoc """
  Avatar component for the Viban design system.
  Shows user image or initials fallback.

  Usage:
    <Avatar src={@user.avatar_url} name={@user.name} />
    <Avatar name="John Doe" size="lg" />
  """
  use Hologram.Component

  prop :src, :string, default: nil
  prop :name, :string, default: ""
  prop :size, :string, default: "md"

  @impl Hologram.Component
  def template do
    ~HOLO"""
    {%if @src}
      <img
        src={@src}
        alt={@name}
        class={avatar_class(@size)}
      />
    {%else}
      <div class={avatar_fallback_class(@size)}>
        <span class={initials_class(@size)}>{initials(@name)}</span>
      </div>
    {/if}
    """
  end

  defp avatar_class(size) do
    "rounded-full object-cover #{size_class(size)}"
  end

  defp avatar_fallback_class(size) do
    "rounded-full bg-brand-600 flex items-center justify-center #{size_class(size)}"
  end

  defp size_class(size) do
    case size do
      "xs" -> "w-6 h-6"
      "sm" -> "w-8 h-8"
      "md" -> "w-10 h-10"
      "lg" -> "w-12 h-12"
      "xl" -> "w-16 h-16"
      _ -> "w-10 h-10"
    end
  end

  defp initials_class(size) do
    text_size =
      case size do
        "xs" -> "text-xs"
        "sm" -> "text-sm"
        "md" -> "text-sm"
        "lg" -> "text-base"
        "xl" -> "text-lg"
        _ -> "text-sm"
      end

    "text-white font-medium #{text_size}"
  end

  defp initials(nil), do: "?"
  defp initials(""), do: "?"

  defp initials(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end
end
