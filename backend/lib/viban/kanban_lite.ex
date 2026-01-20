defmodule Viban.KanbanLite do
  @moduledoc """
  SQLite-backed Kanban domain for LiveView UI.

  This domain provides the same functionality as Viban.Kanban but uses SQLite
  instead of Postgres + Electric SQL. It's designed for simplified deployment
  as a single-binary application via Burrito.

  ## Key Differences from Viban.Kanban

  - Uses SQLite (via AshSqlite) instead of Postgres
  - No Electric SQL sync - uses Phoenix PubSub for real-time updates
  - No TypeScript SDK generation - works directly with LiveView
  - Single database file stored in ~/.viban/viban.db

  ## Resources

  - `Board` - Kanban boards owned by users
  - `Column` - Columns within boards
  - `Task` - Work items in columns
  - `Hook` - Automation definitions
  - `ColumnHook` - Column-specific hook configurations
  - `Repository` - Git repository references
  - `TaskTemplate` - Reusable task templates
  - `PeriodicalTask` - Scheduled recurring tasks
  - `TaskEvent` - Union of all task events (messages, hook executions, etc.)
  """

  use Ash.Domain

  resources do
    resource Viban.KanbanLite.Board
    resource Viban.KanbanLite.Column
    resource Viban.KanbanLite.Task
    resource Viban.KanbanLite.Hook
    resource Viban.KanbanLite.ColumnHook
    resource Viban.KanbanLite.Repository
    resource Viban.KanbanLite.TaskTemplate
    resource Viban.KanbanLite.PeriodicalTask
    resource Viban.KanbanLite.Message
    resource Viban.KanbanLite.HookExecution
    resource Viban.KanbanLite.ExecutorSession
    resource Viban.KanbanLite.ExecutorMessage
  end
end
