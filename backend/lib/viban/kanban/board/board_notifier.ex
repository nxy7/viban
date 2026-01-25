defmodule Viban.Kanban.Board.BoardNotifier do
  @moduledoc """
  Notifier that broadcasts board changes and manages BoardSupervisors.

  When a board is created, notifies the BoardManager to start a BoardSupervisor.
  When a board is deleted, notifies the BoardManager to stop the BoardSupervisor.
  """

  use Ash.Notifier

  alias Viban.Kanban.Actors.BoardManager

  require Logger

  @impl true
  def notify(notification) do
    board = notification.data
    action = notification.action.name

    case action do
      :create ->
        Logger.info("BoardNotifier: Board #{board.id} created, notifying BoardManager")
        BoardManager.notify_board_created(board.id)

      :destroy ->
        Logger.info("BoardNotifier: Board #{board.id} deleted, notifying BoardManager")
        BoardManager.notify_board_deleted(board.id)

      _ ->
        :ok
    end

    :ok
  end
end
