defmodule VibanWeb.PageController do
  use VibanWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
