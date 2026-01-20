defmodule Viban.Kanban do
  @moduledoc """
  SQLite-backed Kanban domain for LiveView UI.

  This domain provides the Kanban board functionality using SQLite
  for simplified deployment without external database dependencies.
  It enables single-binary deployment via Burrito.

  ## Resources

  - `Board` - Kanban boards owned by users
  - `Column` - Columns within boards
  - `Task` - Work items in columns
  - `Hook` - Automation definitions
  - `ColumnHook` - Column-specific hook configurations
  - `Repository` - Git repository references
  - `TaskTemplate` - Reusable task templates
  - `PeriodicalTask` - Scheduled recurring tasks
  - `Message` - Conversation messages between users and AI agents
  - `HookExecution` - History of hook runs
  - `ExecutorSession` - AI executor sessions
  - `ExecutorMessage` - Messages within executor sessions
  """

  use Ash.Domain

  resources do
    resource Viban.Kanban.Board
    resource Viban.Kanban.Column
    resource Viban.Kanban.Task
    resource Viban.Kanban.Hook
    resource Viban.Kanban.ColumnHook
    resource Viban.Kanban.Repository
    resource Viban.Kanban.TaskTemplate
    resource Viban.Kanban.PeriodicalTask
    resource Viban.Kanban.Message
    resource Viban.Kanban.HookExecution
    resource Viban.Kanban.ExecutorSession
    resource Viban.Kanban.ExecutorMessage
  end
end
