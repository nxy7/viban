defmodule VibanWeb.Live.BoardLiveTest do
  use VibanWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "board page" do
    setup %{conn: conn} do
      user = create_user()
      conn = log_in_user(conn, user)
      %{board: board} = board_data = create_board_with_columns(user)

      %{conn: conn, user: user, board: board, board_data: board_data}
    end

    test "renders board with columns", %{conn: conn, board: board} do
      {:ok, _view, html} = live(conn, "/board/#{board.id}")

      assert html =~ board.name
      assert html =~ "TODO"
      assert html =~ "In Progress"
      assert html =~ "To Review"
      assert html =~ "Done"
    end

    test "shows new task button", %{conn: conn, board: board} do
      {:ok, _view, html} = live(conn, "/board/#{board.id}")

      assert html =~ "New Task"
    end

    test "displays tasks in correct columns", %{conn: conn, board: board, board_data: board_data} do
      _task1 = create_task(board_data.todo, %{title: "Task in TODO"})
      _task2 = create_task(board_data.in_progress, %{title: "Task in Progress"})

      {:ok, _view, html} = live(conn, "/board/#{board.id}")

      assert html =~ "Task in TODO"
      assert html =~ "Task in Progress"
    end

    test "can filter tasks by search", %{conn: conn, board: board, board_data: board_data} do
      _task1 = create_task(board_data.todo, %{title: "Important Task"})
      _task2 = create_task(board_data.todo, %{title: "Other Work"})

      {:ok, view, html} = live(conn, "/board/#{board.id}")

      assert html =~ "Important Task"
      assert html =~ "Other Work"

      view
      |> element("#search-input")
      |> render_keyup(%{value: "Important"})

      html = render(view)
      assert html =~ "Important Task"
      refute html =~ "Other Work"
    end

    test "can open settings panel", %{conn: conn, board: board} do
      {:ok, view, _html} = live(conn, "/board/#{board.id}")

      view
      |> element("button", "Settings")
      |> render_click()

      html = render(view)
      assert html =~ "Board Settings"
    end
  end

  describe "task card interaction" do
    setup %{conn: conn} do
      user = create_user()
      conn = log_in_user(conn, user)
      %{board: board} = board_data = create_board_with_columns(user)
      task = create_task(board_data.todo, %{title: "Test Task"})

      %{conn: conn, user: user, board: board, board_data: board_data, task: task}
    end

    test "can click on task card", %{conn: conn, board: board, task: task} do
      {:ok, view, _html} = live(conn, "/board/#{board.id}")

      view
      |> element("#task-#{task.id}")
      |> render_click()

      assert_patch(view, "/board/#{board.id}/task/#{task.id}")
    end
  end
end
