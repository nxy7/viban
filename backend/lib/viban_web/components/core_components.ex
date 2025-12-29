defmodule VibanWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component

  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"

  def flash(assigns) do
    ~H"""
    """
  end
end
