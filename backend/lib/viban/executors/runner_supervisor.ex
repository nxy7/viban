defmodule Viban.Executors.RunnerSupervisor do
  @moduledoc """
  DynamicSupervisor for executor runner processes.

  Each executor runs as a separate GenServer under this supervisor,
  allowing for concurrent task execution and proper process isolation.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  List all running executor processes.
  """
  def list_running do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  @doc """
  Count of running executors.
  """
  def count_running do
    DynamicSupervisor.count_children(__MODULE__).active
  end
end
