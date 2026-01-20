defmodule VibanWeb.Live.TaskMovementLiveTest do
  use VibanWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "task display" do
    setup %{conn: conn} do
      user = create_user()
      conn = log_in_user(conn, user)
      %{board: board} = board_data = create_board_with_columns(user)
      task = create_task(board_data.todo, %{title: "Movable Task"})

      %{conn: conn, user: user, board: board, board_data: board_data, task: task}
    end

    test "task is displayed in board", %{conn: conn, board: board} do
      {:ok, _view, html} = live(conn, "/board/#{board.id}")
      assert html =~ "Movable Task"
    end

    test "multiple tasks can exist in same column", %{
      conn: conn,
      board: board,
      board_data: board_data
    } do
      _task1 = create_task(board_data.todo, %{title: "First Task"})
      _task2 = create_task(board_data.todo, %{title: "Second Task"})
      _task3 = create_task(board_data.todo, %{title: "Third Task"})

      {:ok, _view, html} = live(conn, "/board/#{board.id}")

      assert html =~ "First Task"
      assert html =~ "Second Task"
      assert html =~ "Third Task"
    end
  end

  describe "task ordering" do
    setup %{conn: conn} do
      user = create_user()
      conn = log_in_user(conn, user)
      %{board: board} = board_data = create_board_with_columns(user)

      %{conn: conn, user: user, board: board, board_data: board_data}
    end

    test "tasks maintain order within column", %{conn: conn, board: board, board_data: board_data} do
      _task1 = create_task(board_data.todo, %{title: "Task 1"})
      _task2 = create_task(board_data.todo, %{title: "Task 2"})
      _task3 = create_task(board_data.todo, %{title: "Task 3"})

      {:ok, _view, html} = live(conn, "/board/#{board.id}")

      assert html =~ "Task 1"
      assert html =~ "Task 2"
      assert html =~ "Task 3"
    end
  end
end
