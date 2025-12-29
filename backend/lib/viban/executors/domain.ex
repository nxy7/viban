defmodule Viban.Executors do
  @moduledoc """
  Ash Domain for executor management.

  This domain provides resources for:
  - Querying available executors
  - Starting executor sessions
  - Managing executor lifecycle

  The Executor resource is virtual (no data layer) - it represents
  the available CLI tools on the system.
  """

  use Ash.Domain

  resources do
    resource Viban.Executors.Executor
    resource Viban.Executors.ExecutorSession
    resource Viban.Executors.ExecutorMessage
  end
end
