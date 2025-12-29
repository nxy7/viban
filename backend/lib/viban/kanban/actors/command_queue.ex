defmodule Viban.Kanban.Actors.CommandQueue do
  @moduledoc """
  Command queue for sequential task execution.

  Commands are executed one at a time in FIFO order. Each command can have
  an optional callback that runs after completion.

  ## Command Structure

  Commands are maps with:
  - `:type` - atom identifying the command type
  - `:data` - command-specific data
  - `:on_complete` - optional callback `(result -> :ok | {:queue, [command]})`
  - `:on_error` - optional callback `(error -> :ok | {:queue, [command]})`

  ## Command Types

  - `:hook_entry` - Run an onEntry hook
  - `:hook_cleanup` - Run a persistent hook cleanup
  - `:hook_persistent_start` - Start a persistent hook
  - `:executor_start` - Start the AI executor
  - `:executor_stop` - Stop the AI executor
  - `:move_task` - Move task to a column (system-initiated)

  ## Example

      queue = CommandQueue.new()
      queue = CommandQueue.push(queue, %{
        type: :executor_start,
        data: %{prompt: "..."},
        on_complete: fn _result ->
          {:queue, [%{type: :move_task, data: %{column_id: to_review_id}}]}
        end
      })

  ## Interruption

  Some commands (like `:executor_start`) are interruptible. When interrupted:
  1. Current command's cleanup is run
  2. Remaining queue is cleared
  3. New commands are queued

  """

  @type command :: %{
          type: atom(),
          data: map(),
          on_complete: (term() -> :ok | {:queue, [command()]}) | nil,
          on_error: (term() -> :ok | {:queue, [command()]}) | nil
        }

  @type t :: %__MODULE__{
          queue: :queue.queue(command()),
          current: command() | nil,
          interrupted: boolean()
        }

  defstruct queue: :queue.new(), current: nil, interrupted: false

  @doc """
  Creates a new empty command queue.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Pushes a command to the end of the queue.
  """
  @spec push(t(), command()) :: t()
  def push(%__MODULE__{queue: q} = state, command) do
    %{state | queue: :queue.in(command, q)}
  end

  @doc """
  Pushes multiple commands to the end of the queue.
  """
  @spec push_all(t(), [command()]) :: t()
  def push_all(state, commands) do
    Enum.reduce(commands, state, &push(&2, &1))
  end

  @doc """
  Pushes a command to the front of the queue (priority).
  """
  @spec push_front(t(), command()) :: t()
  def push_front(%__MODULE__{queue: q} = state, command) do
    new_queue = :queue.in_r(command, q)
    %{state | queue: new_queue}
  end

  @doc """
  Pushes multiple commands to the front of the queue.
  Commands are added in order, so first command in list will be first to execute.
  """
  @spec push_front_all(t(), [command()]) :: t()
  def push_front_all(state, commands) do
    # Reverse so first command ends up at front after all pushes
    Enum.reduce(Enum.reverse(commands), state, &push_front(&2, &1))
  end

  @doc """
  Pops the next command from the queue.
  Returns `{:ok, command, new_state}` or `:empty`.
  """
  @spec pop(t()) :: {:ok, command(), t()} | :empty
  def pop(%__MODULE__{queue: q} = state) do
    case :queue.out(q) do
      {{:value, command}, new_queue} ->
        {:ok, command, %{state | queue: new_queue, current: command}}

      {:empty, _} ->
        :empty
    end
  end

  @doc """
  Marks the current command as complete.
  """
  @spec complete_current(t()) :: t()
  def complete_current(state) do
    %{state | current: nil}
  end

  @doc """
  Clears all pending commands from the queue.
  Does not affect the current running command.
  """
  @spec clear(t()) :: t()
  def clear(state) do
    %{state | queue: :queue.new()}
  end

  @doc """
  Marks the queue as interrupted. The current command should stop.
  """
  @spec interrupt(t()) :: t()
  def interrupt(state) do
    %{state | interrupted: true}
  end

  @doc """
  Clears the interrupted flag.
  """
  @spec clear_interrupt(t()) :: t()
  def clear_interrupt(state) do
    %{state | interrupted: false}
  end

  @doc """
  Returns true if the queue is interrupted.
  """
  @spec interrupted?(t()) :: boolean()
  def interrupted?(%__MODULE__{interrupted: interrupted}), do: interrupted

  @doc """
  Returns true if a command is currently executing.
  """
  @spec executing?(t()) :: boolean()
  def executing?(%__MODULE__{current: current}), do: not is_nil(current)

  @doc """
  Returns true if the queue is empty (no pending commands).
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{queue: q}), do: :queue.is_empty(q)

  @doc """
  Returns the number of pending commands.
  """
  @spec length(t()) :: non_neg_integer()
  def length(%__MODULE__{queue: q}), do: :queue.len(q)

  @doc """
  Returns the current command being executed, if any.
  """
  @spec current(t()) :: command() | nil
  def current(%__MODULE__{current: current}), do: current

  @doc """
  Removes commands of a specific type from the queue.
  """
  @spec remove_type(t(), atom()) :: t()
  def remove_type(%__MODULE__{queue: q} = state, type) do
    new_queue =
      q
      |> :queue.to_list()
      |> Enum.reject(&(&1.type == type))
      |> :queue.from_list()

    %{state | queue: new_queue}
  end

  @doc """
  Returns all pending commands as a list (for debugging).
  """
  @spec to_list(t()) :: [command()]
  def to_list(%__MODULE__{queue: q}), do: :queue.to_list(q)
end
