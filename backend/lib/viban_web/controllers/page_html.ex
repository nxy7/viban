defmodule VibanWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.
  """
  use VibanWeb, :html

  embed_templates "page_html/*"
end
