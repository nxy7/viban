# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

alias Viban.Kanban.Board
alias Viban.Kanban.Column
alias Viban.Kanban.ColumnHook
alias Viban.Kanban.Hook
alias Viban.Messages.TestMessage
alias Viban.TestSupport

require Ash.Query

# Create the initial test message if it doesn't exist
action_input = Ash.ActionInput.for_action(TestMessage, :get_or_create, %{})

case Ash.run_action(action_input) do
  {:ok, message} ->
    IO.puts("Test message ready: #{message.text}")

  {:error, error} ->
    IO.puts("Error creating test message: #{inspect(error)}")
end

# Create default Kanban board if none exists with this name
# Note: Columns are automatically created by the Board :create action after_action hook
board =
  Board
  |> Ash.Query.filter(name == "My Kanban Board")
  |> Ash.read_one()
  |> case do
    {:ok, nil} ->
      IO.puts("Creating default Kanban board...")

      {:ok, board} =
        Ash.create(Board, %{
          name: "My Kanban Board",
          description: "Default project board"
        })

      IO.puts("Created board: #{board.name}")

      IO.puts("Default columns (TODO, In Progress, To Review, Done, Cancelled) created automatically")

      board

    {:ok, board} ->
      IO.puts("Kanban board already exists: #{board.name}")
      board

    {:error, error} ->
      IO.puts("Error checking boards: #{inspect(error)}")
      nil
  end

# ============================================================================
# E2E Test Seed Boards
# ============================================================================

# Create test user for E2E tests
test_user =
  case TestSupport.get_or_create_test_user() do
    {:ok, user} ->
      IO.puts("\nTest user ready: #{user.name} (#{user.email})")
      user

    {:error, error} ->
      IO.puts("Error creating test user: #{inspect(error)}")
      nil
  end

if test_user do
  # Board 1: E2E Test Board (No Hooks) - for testing task movement and reordering
  e2e_no_hooks_board =
    Board
    |> Ash.Query.filter(user_id == ^test_user.id and name == "E2E Test Board (No Hooks)")
    |> Ash.read_one!()

  if is_nil(e2e_no_hooks_board) do
    IO.puts("\nCreating E2E Test Board (No Hooks)...")

    {:ok, e2e_board} =
      Ash.create(Board, %{
        name: "E2E Test Board (No Hooks)",
        description: "Board for E2E tests - task movement and reordering without hooks",
        user_id: test_user.id
      })

    IO.puts("Created board: #{e2e_board.name}")

    {:ok, columns} = Column |> Ash.Query.filter(board_id == ^e2e_board.id) |> Ash.read()

    todo_col = Enum.find(columns, &(&1.name == "TODO"))

    if todo_col do
      for i <- 1..3 do
        {:ok, _task} =
          Ash.create(Viban.Kanban.Task, %{
            title: "Test Task #{i}",
            description: "Sample task #{i} for drag and drop testing",
            column_id: todo_col.id,
            position: i * 1000.0
          })
      end

      IO.puts("Created 3 sample tasks in TODO column")
    end
  else
    IO.puts("\nE2E Test Board (No Hooks) already exists")
  end

  # Board 2: E2E Test Board (Slow Hook) - for testing hook cancellation
  e2e_slow_hook_board =
    Board
    |> Ash.Query.filter(user_id == ^test_user.id and name == "E2E Test Board (Slow Hook)")
    |> Ash.read_one!()

  if is_nil(e2e_slow_hook_board) do
    IO.puts("\nCreating E2E Test Board (Slow Hook)...")

    {:ok, e2e_board} =
      Ash.create(Board, %{
        name: "E2E Test Board (Slow Hook)",
        description: "Board for E2E tests - hook cancellation testing",
        user_id: test_user.id
      })

    IO.puts("Created board: #{e2e_board.name}")

    {:ok, slow_hook} =
      Hook.create(%{
        name: "Slow Test Hook (30s)",
        command: "echo 'Starting slow hook...' && sleep 30 && echo 'Slow hook completed!'",
        board_id: e2e_board.id
      })

    IO.puts("Created hook: #{slow_hook.name}")

    {:ok, columns} = Column |> Ash.Query.filter(board_id == ^e2e_board.id) |> Ash.read()
    in_progress_col = Enum.find(columns, &(&1.name == "In Progress"))
    todo_col = Enum.find(columns, &(&1.name == "TODO"))

    if in_progress_col do
      {:ok, _} =
        ColumnHook.create(%{
          hook_type: :on_entry,
          position: 0,
          column_id: in_progress_col.id,
          hook_id: slow_hook.id
        })

      IO.puts("Assigned slow hook to 'In Progress' column")
    end

    if todo_col do
      {:ok, _task} =
        Ash.create(Viban.Kanban.Task, %{
          title: "Hook Cancellation Test Task",
          description: "Move this task to In Progress to trigger the slow hook",
          column_id: todo_col.id,
          position: 1000.0
        })

      IO.puts("Created test task for hook cancellation testing")
    end
  else
    IO.puts("\nE2E Test Board (Slow Hook) already exists")
  end
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

        IO.puts("Assigned persistent hook '#{touch_hook.name}' to column '#{in_progress_col.name}'")

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

      IO.puts("Hook deduplication is set up: 'Touch Test File' hook is on both 'In Progress' and 'To Review'")

      IO.puts("Moving a task between these columns will NOT trigger cleanup/restart of that hook.")

    {:ok, hooks} ->
      IO.puts("Hooks already exist (#{length(hooks)} hooks found)")

    {:error, error} ->
      IO.puts("Error checking hooks: #{inspect(error)}")
  end
end
