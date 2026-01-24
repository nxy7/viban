defmodule VibanWeb.Hologram.UI.Card do
  @moduledoc """
  Card container component for the Viban design system.

  Usage:
    <Card>
      <CardHeader>Title</CardHeader>
      <CardBody>Content</CardBody>
    </Card>

    <Card hover={true} padding="lg">
      Clickable card content
    </Card>
  """
  use Hologram.Component

  prop :hover, :boolean, default: false
  prop :padding, :string, default: "md"
  prop :border, :boolean, default: true

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class={card_class(@hover, @padding, @border)}>
      <slot />
    </div>
    """
  end

  defp card_class(hover, padding, border) do
    base = "bg-gray-900 rounded-xl"

    padding_class =
      case padding do
        "none" -> ""
        "sm" -> "p-3"
        "md" -> "p-4"
        "lg" -> "p-6"
        _ -> "p-4"
      end

    border_class =
      if border do
        if hover do
          "border border-gray-800 hover:border-gray-700"
        else
          "border border-gray-800"
        end
      else
        ""
      end

    hover_class =
      if hover do
        "hover:bg-gray-800/50 transition-all cursor-pointer"
      else
        ""
      end

    [base, padding_class, border_class, hover_class]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end
end

defmodule VibanWeb.Hologram.UI.CardHeader do
  @moduledoc """
  Card header component.

  Usage:
    <CardHeader>
      <h3>Title</h3>
    </CardHeader>
  """
  use Hologram.Component

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="pb-3 mb-3 border-b border-gray-800">
      <slot />
    </div>
    """
  end
end

defmodule VibanWeb.Hologram.UI.CardBody do
  @moduledoc """
  Card body component.

  Usage:
    <CardBody>
      <p>Content here</p>
    </CardBody>
  """
  use Hologram.Component

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div>
      <slot />
    </div>
    """
  end
end
