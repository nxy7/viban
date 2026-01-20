defmodule VibanWeb.Live.HomeLiveTest do
  use VibanWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "home page" do
    test "renders home page with no boards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Viban Kanban"
      assert html =~ "No boards yet"
    end

    test "shows boards list when boards exist", %{conn: conn} do
      user = create_user()
      conn = log_in_user(conn, user)
      _board = create_board(user, %{name: "My Test Board"})

      {:ok, _view, html} = live(conn, "/")

      assert html =~ "My Test Board"
      refute html =~ "No boards yet"
    end

    test "shows login button when not authenticated", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Sign in with GitHub"
    end

    test "shows user info when authenticated", %{conn: conn} do
      user = create_user(%{provider_login: "testlogin"})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/")

      assert html =~ "testlogin"
      assert html =~ "Logout"
    end
  end
end
