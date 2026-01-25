defmodule Viban.Executors do
  @moduledoc """
  Ash Domain for executor management.

  This domain provides resources for:
  - Querying available executors

  The Executor resource is virtual (no data layer) - it represents
  the available CLI tools on the system.

  Note: ExecutorSession and ExecutorMessage have moved to the Kanban domain
  as part of the unified task_events table.
  """

  use Ash.Domain

  resources do
    resource Viban.Executors.Executor
  end
end
