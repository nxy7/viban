defmodule Viban.Kanban.SystemHooks.Behaviour do
  @moduledoc """
  Behaviour for system hooks. All system hooks must implement this behaviour.
  System hooks are virtual - they exist in code, not in the database.

  All hooks are executed when a task enters a column (on_entry only).
  """

  alias Viban.Kanban.Column
  alias Viban.Kanban.Task

  @doc "Unique identifier for the hook (format: system:<name>)"
  @callback id() :: String.t()

  @doc "Human-readable name"
  @callback name() :: String.t()

  @doc "Description of what the hook does"
  @callback description() :: String.t()

  @doc "Execute the hook when a task enters the column"
  @callback execute(task :: Task.t(), column :: Column.t(), opts :: keyword()) ::
              :ok | {:await_executor, Ecto.UUID.t()} | {:error, term()}
end
