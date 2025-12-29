# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

alias Viban.Messages.TestMessage
alias Viban.Kanban.{Board, Column, Hook, ColumnHook}

# Create the initial test message if it doesn't exist
action_input = Ash.ActionInput.for_action(TestMessage, :get_or_create, %{})

case Ash.run_action(action_input) do
  {:ok, message} ->
    IO.puts("Test message ready: #{message.text}")

  {:error, error} ->
    IO.puts("Error creating test message: #{inspect(error)}")
end

# Create default Kanban board if none exists
# Note: Columns are automatically created by the Board :create action after_action hook
board =
  case Ash.read(Board) do
    {:ok, []} ->
      IO.puts("Creating default Kanban board...")

      {:ok, board} =
        Ash.create(Board, %{
          name: "My Kanban Board",
          description: "Default project board"
        })

      IO.puts("Created board: #{board.name}")

      IO.puts(
        "Default columns (TODO, In Progress, To Review, Done, Cancelled) created automatically"
      )

      board

    {:ok, [board | _]} ->
      IO.puts("Kanban board already exists: #{board.name}")
      board

    {:error, error} ->
      IO.puts("Error checking boards: #{inspect(error)}")
      nil
  end

# Create sample hooks for the board if they don't exist
if board do
  case Ash.read(Hook) do
    {:ok, []} ->
      IO.puts("\nCreating sample hooks for board #{board.id}...")

      # Create sample hooks
      {:ok, touch_hook} =
        Hook.create(%{
          name: "Touch Test File",
          command: "touch test_file.txt && echo 'Test file created'",
          cleanup_command: "rm -f test_file.txt && echo 'Test file removed'",
          working_directory: :worktree,
          timeout_ms: 10_000,
          board_id: board.id
        })

      IO.puts("Created hook: #{touch_hook.name}")

      {:ok, echo_hook} =
        Hook.create(%{
          name: "Echo Entry",
          command: "echo 'Task entered column at $(date)'",
          working_directory: :worktree,
          timeout_ms: 5_000,
          board_id: board.id
        })

      IO.puts("Created hook: #{echo_hook.name}")

      {:ok, notify_hook} =
        Hook.create(%{
          name: "Notify Leave",
          command: "echo 'Task leaving column at $(date)'",
          working_directory: :worktree,
          timeout_ms: 5_000,
          board_id: board.id
        })

      IO.puts("Created hook: #{notify_hook.name}")

      # Get columns for the board
      {:ok, columns} = Ash.read(Column)
      board_columns = Enum.filter(columns, &(&1.board_id == board.id))

      in_progress_col = Enum.find(board_columns, &(&1.name == "In Progress"))
      in_review_col = Enum.find(board_columns, &(&1.name == "To Review"))
      done_col = Enum.find(board_columns, &(&1.name == "Done"))

      # Assign hooks to columns
      if in_progress_col do
        # Persistent hook on In Progress - will run cleanup when leaving
        {:ok, _} =
          ColumnHook.create(%{
            hook_type: :persistent,
            position: 0,
            column_id: in_progress_col.id,
            hook_id: touch_hook.id
          })

        IO.puts(
          "Assigned persistent hook '#{touch_hook.name}' to column '#{in_progress_col.name}'"
        )

        # On entry hook
        {:ok, _} =
          ColumnHook.create(%{
            hook_type: :on_entry,
            position: 0,
            column_id: in_progress_col.id,
            hook_id: echo_hook.id
          })

        IO.puts("Assigned on_entry hook '#{echo_hook.name}' to column '#{in_progress_col.name}'")
      end

      if in_review_col do
        # Same persistent hook on In Review (will NOT cleanup when moving from In Progress)
        {:ok, _} =
          ColumnHook.create(%{
            hook_type: :persistent,
            position: 0,
            column_id: in_review_col.id,
            hook_id: touch_hook.id
          })

        IO.puts("Assigned persistent hook '#{touch_hook.name}' to column '#{in_review_col.name}'")
      end

      if done_col do
        # On entry hook for Done
        {:ok, _} =
          ColumnHook.create(%{
            hook_type: :on_entry,
            position: 0,
            column_id: done_col.id,
            hook_id: echo_hook.id
          })

        IO.puts("Assigned on_entry hook '#{echo_hook.name}' to column '#{done_col.name}'")
      end

      IO.puts("\nSample hooks created and assigned to columns!")

      IO.puts(
        "Hook deduplication is set up: 'Touch Test File' hook is on both 'In Progress' and 'To Review'"
      )

      IO.puts(
        "Moving a task between these columns will NOT trigger cleanup/restart of that hook."
      )

    {:ok, hooks} ->
      IO.puts("Hooks already exist (#{length(hooks)} hooks found)")

    {:error, error} ->
      IO.puts("Error checking hooks: #{inspect(error)}")
  end
end
