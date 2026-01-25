defmodule Viban.CallerTracking do
  @moduledoc """
  Propagates caller tracking through GenServers for Ecto Sandbox compatibility in async tests.

  The Ecto SQL Sandbox uses the `:"$callers"` process dictionary key to automatically
  allow spawned processes to share the test's database connection. This works automatically
  for `Task` and `Task.Supervisor`, but GenServers need manual propagation.

  ## Usage in GenServers

  Use `capture_callers/0` in `start_link` and `restore_callers/1` in `init`:

      def start_link(args) do
        callers = Viban.CallerTracking.capture_callers()
        GenServer.start_link(__MODULE__, {callers, args}, name: via_tuple(args))
      end

      def init({callers, args}) do
        Viban.CallerTracking.restore_callers(callers)
        {:ok, %{...}}
      end

  ## Why This Is Needed

  When tests use `async: true`, each test gets its own database sandbox. Child processes
  spawned by the test need to access the same sandbox. The `:"$callers"` mechanism
  allows the sandbox to trace back through the process ancestry to find the owning test.

  GenServers don't propagate this automatically because `start_link` runs in the caller
  process, but `init` runs in the new GenServer process.
  """

  @doc """
  Captures the current caller chain plus this process for later restoration.

  Call this in `start_link` (which runs in the caller's context).
  """
  @spec capture_callers() :: [pid()]
  def capture_callers do
    callers = Process.get(:"$callers") || []
    [self() | callers]
  end

  @doc """
  Restores the caller chain in the current process.

  Call this in `init` (which runs in the GenServer's context).
  """
  @spec restore_callers([pid()]) :: :ok
  def restore_callers(callers) do
    Process.put(:"$callers", callers)
    :ok
  end

  @doc """
  Wraps args with captured callers for passing to GenServer.start_link.

  Convenience function that combines capture and wrapping.
  """
  @spec wrap_args(term()) :: {[pid()], term()}
  def wrap_args(args) do
    {capture_callers(), args}
  end

  @doc """
  Unwraps args and restores callers in init.

  Returns the original args after restoring the caller chain.
  """
  @spec unwrap_args({[pid()], term()}) :: term()
  def unwrap_args({callers, args}) do
    restore_callers(callers)
    args
  end
end
