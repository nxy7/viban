defmodule VibanWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by tests that
  require setting up a connection and LiveView tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Plug.Conn
      import VibanWeb.ConnCase

      alias VibanWeb.Router.Helpers, as: Routes

      @endpoint VibanWeb.Endpoint
    end
  end

  setup tags do
    Viban.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def create_user(attrs \\ %{}) do
    default_attrs = %{
      provider: :github,
      provider_uid: "test-uid-#{System.unique_integer([:positive])}",
      provider_login: "testuser",
      name: "Test User",
      email: "test@example.com",
      access_token: "test-token"
    }

    {:ok, user} = Viban.Accounts.User.create(Map.merge(default_attrs, attrs))
    user
  end

  def log_in_user(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end

  def create_board(user, attrs \\ %{}) do
    default_attrs = %{
      name: "Test Board",
      user_id: user.id
    }

    {:ok, board} = Viban.KanbanLite.Board.create(Map.merge(default_attrs, attrs))
    board
  end

  def create_board_with_columns(user) do
    board = create_board(user)
    columns = Viban.KanbanLite.Column.for_board!(board.id)

    todo = Enum.find(columns, &(&1.name == "TODO"))
    in_progress = Enum.find(columns, &(&1.name == "In Progress"))
    to_review = Enum.find(columns, &(&1.name == "To Review"))
    done = Enum.find(columns, &(&1.name == "Done"))

    %{
      board: board,
      columns: columns,
      todo: todo,
      in_progress: in_progress,
      to_review: to_review,
      done: done
    }
  end

  def create_task(column, attrs \\ %{}) do
    default_attrs = %{
      title: "Test Task",
      column_id: column.id
    }

    {:ok, task} = Viban.KanbanLite.Task.create(Map.merge(default_attrs, attrs))
    task
  end
end
