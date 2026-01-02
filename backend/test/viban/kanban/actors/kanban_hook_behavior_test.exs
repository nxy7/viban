defmodule Viban.Kanban.Actors.KanbanHookBehaviorTest do
  @moduledoc """
  Tests for kanban hook behavior including:
  - Hook execution when task enters a column
  - Hook short-circuiting when task is moved manually
  - Hook queueing and sequential execution
  - execute_once flag behavior
  - Error handling and task error states
  """
  use Viban.DataCase, async: false

  alias Viban.Kanban.{Board, Column, Task, Hook, ColumnHook}
  alias Viban.Kanban.Actors.BoardActor
  alias Viban.Kanban.Actors.CommandQueue

  # Integration tests require the full actor system to be running.
  # Run them with: mix test --include integration
  @moduletag :unit

  # Timeout for async operations (hooks, moves, etc.)
  @async_timeout 2000

  describe "CommandQueue module" do
    test "new queue is empty and not executing" do
      queue = CommandQueue.new()

      assert CommandQueue.empty?(queue)
      refute CommandQueue.executing?(queue)
    end

    test "can push single command" do
      queue = CommandQueue.new()

      command = %{type: :test, data: %{foo: :bar}}
      queue = CommandQueue.push(queue, command)

      refute CommandQueue.empty?(queue)
    end

    test "can push multiple commands" do
      queue = CommandQueue.new()

      commands = [
        %{type: :test1, data: %{}},
        %{type: :test2, data: %{}},
        %{type: :test3, data: %{}}
      ]

      queue = CommandQueue.push_all(queue, commands)

      refute CommandQueue.empty?(queue)
    end

    test "pop returns commands in FIFO order" do
      queue = CommandQueue.new()

      commands = [
        %{type: :first, data: %{}},
        %{type: :second, data: %{}},
        %{type: :third, data: %{}}
      ]

      queue = CommandQueue.push_all(queue, commands)

      {:ok, cmd1, queue} = CommandQueue.pop(queue)
      assert cmd1.type == :first

      queue = CommandQueue.complete_current(queue)

      {:ok, cmd2, queue} = CommandQueue.pop(queue)
      assert cmd2.type == :second

      queue = CommandQueue.complete_current(queue)

      {:ok, cmd3, _queue} = CommandQueue.pop(queue)
      assert cmd3.type == :third
    end

    test "clear empties the queue" do
      queue = CommandQueue.new()

      commands = [
        %{type: :test1, data: %{}},
        %{type: :test2, data: %{}}
      ]

      queue = CommandQueue.push_all(queue, commands)
      queue = CommandQueue.clear(queue)

      assert CommandQueue.empty?(queue)
    end

    test "executing flag is set during pop and cleared after complete" do
      queue = CommandQueue.new()

      command = %{type: :test, data: %{}}
      queue = CommandQueue.push(queue, command)

      refute CommandQueue.executing?(queue)

      {:ok, _cmd, queue} = CommandQueue.pop(queue)
      assert CommandQueue.executing?(queue)

      queue = CommandQueue.complete_current(queue)
      refute CommandQueue.executing?(queue)
    end
  end

  describe "hook execution on task entry" do
    @describetag :integration

    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", user_id: user.id})

      {:ok, columns} = Column.read()
      board_columns = Enum.filter(columns, &(&1.board_id == board.id))
      todo_column = Enum.find(board_columns, &(&1.name == "TODO"))
      in_progress_column = Enum.find(board_columns, &(&1.name == "In Progress"))
      to_review_column = Enum.find(board_columns, &(&1.name == "To Review"))

      %{
        board: board,
        todo_column: todo_column,
        in_progress_column: in_progress_column,
        to_review_column: to_review_column,
        user: user
      }
    end

    test "hook runs when task enters column", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      # Create a script hook that creates a marker file
      marker_file = Path.join(System.tmp_dir!(), "hook_executed_#{System.unique_integer()}")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Marker Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      # Attach hook to In Progress column
      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0
        })

      # Create task in TODO
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      # Start board actor to manage task actors
      start_supervised!({BoardActor, board.id})
      Process.sleep(200)

      # Move task to In Progress
      {:ok, moved_task} = Task.move(task, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved_task)

      # Wait for hook to execute
      Process.sleep(@async_timeout)

      # Verify marker file was created
      assert File.exists?(marker_file)

      # Cleanup
      File.rm(marker_file)
    end

    test "hooks execute in position order", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      # Create marker file that we'll append to
      marker_file = Path.join(System.tmp_dir!(), "hook_order_#{System.unique_integer()}")

      # Create three hooks that append their position to a file
      {:ok, hook1} =
        Hook.create_script_hook(%{
          name: "Hook 1",
          command: "echo 'first' >> #{marker_file}",
          board_id: board.id
        })

      {:ok, hook2} =
        Hook.create_script_hook(%{
          name: "Hook 2",
          command: "echo 'second' >> #{marker_file}",
          board_id: board.id
        })

      {:ok, hook3} =
        Hook.create_script_hook(%{
          name: "Hook 3",
          command: "echo 'third' >> #{marker_file}",
          board_id: board.id
        })

      # Attach hooks in specific order
      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook1.id,
          position: 0
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook2.id,
          position: 1
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook3.id,
          position: 2
        })

      # Create task in TODO
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      # Start board actor
      start_supervised!({BoardActor, board.id})
      Process.sleep(200)

      # Move task to In Progress
      {:ok, moved_task} = Task.move(task, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved_task)

      # Wait for all hooks to execute
      Process.sleep(@async_timeout * 2)

      # Verify execution order
      assert File.exists?(marker_file)
      content = File.read!(marker_file)
      lines = String.split(content, "\n", trim: true)

      assert lines == ["first", "second", "third"]

      # Cleanup
      File.rm(marker_file)
    end
  end

  describe "execute_once flag behavior" do
    @describetag :integration

    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", user_id: user.id})

      {:ok, columns} = Column.read()
      board_columns = Enum.filter(columns, &(&1.board_id == board.id))
      todo_column = Enum.find(board_columns, &(&1.name == "TODO"))
      in_progress_column = Enum.find(board_columns, &(&1.name == "In Progress"))

      %{
        board: board,
        todo_column: todo_column,
        in_progress_column: in_progress_column,
        user: user
      }
    end

    test "execute_once=true hook only runs once per task", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      # Create a hook that increments a counter file
      counter_file = Path.join(System.tmp_dir!(), "hook_counter_#{System.unique_integer()}")
      # Initialize counter
      File.write!(counter_file, "0")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Counter Hook",
          command: "expr $(cat #{counter_file}) + 1 > #{counter_file}",
          board_id: board.id
        })

      # Attach hook with execute_once=true
      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0,
          execute_once: true
        })

      # Create task in TODO
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      # Start board actor
      start_supervised!({BoardActor, board.id})
      Process.sleep(200)

      # First move to In Progress - hook should run
      {:ok, moved1} = Task.move(task, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved1)
      Process.sleep(@async_timeout)

      # Check counter
      assert String.trim(File.read!(counter_file)) == "1"

      # Move back to TODO
      {:ok, moved2} = Task.move(moved1, %{column_id: todo_column.id})
      BoardActor.notify_task_updated(board.id, moved2)
      Process.sleep(500)

      # Move to In Progress again - hook should NOT run
      {:ok, moved3} = Task.move(moved2, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved3)
      Process.sleep(@async_timeout)

      # Counter should still be 1
      assert String.trim(File.read!(counter_file)) == "1"

      # Cleanup
      File.rm(counter_file)
    end

    test "execute_once=false hook runs every time task enters column", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      # Create a hook that increments a counter file
      counter_file = Path.join(System.tmp_dir!(), "hook_counter_#{System.unique_integer()}")
      File.write!(counter_file, "0")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Counter Hook",
          command: "expr $(cat #{counter_file}) + 1 > #{counter_file}",
          board_id: board.id
        })

      # Attach hook with execute_once=false (default)
      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0,
          execute_once: false
        })

      # Create task in TODO
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      # Start board actor
      start_supervised!({BoardActor, board.id})
      Process.sleep(200)

      # First move to In Progress
      {:ok, moved1} = Task.move(task, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved1)
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "1"

      # Move back to TODO
      {:ok, moved2} = Task.move(moved1, %{column_id: todo_column.id})
      BoardActor.notify_task_updated(board.id, moved2)
      Process.sleep(500)

      # Move to In Progress again - hook SHOULD run again
      {:ok, moved3} = Task.move(moved2, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved3)
      Process.sleep(@async_timeout)

      # Counter should now be 2
      assert String.trim(File.read!(counter_file)) == "2"

      # Cleanup
      File.rm(counter_file)
    end
  end

  describe "hook short-circuiting" do
    @describetag :integration

    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", user_id: user.id})

      {:ok, columns} = Column.read()
      board_columns = Enum.filter(columns, &(&1.board_id == board.id))
      todo_column = Enum.find(board_columns, &(&1.name == "TODO"))
      in_progress_column = Enum.find(board_columns, &(&1.name == "In Progress"))
      to_review_column = Enum.find(board_columns, &(&1.name == "To Review"))

      %{
        board: board,
        todo_column: todo_column,
        in_progress_column: in_progress_column,
        to_review_column: to_review_column,
        user: user
      }
    end

    test "moving task clears remaining hook queue", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      to_review_column: to_review_column
    } do
      # Create a slow hook and a second hook that shouldn't run
      marker_file = Path.join(System.tmp_dir!(), "shortcircuit_#{System.unique_integer()}")

      {:ok, slow_hook} =
        Hook.create_script_hook(%{
          name: "Slow Hook",
          # Sleep for 3 seconds
          command: "sleep 3 && echo 'slow' >> #{marker_file}",
          board_id: board.id
        })

      {:ok, fast_hook} =
        Hook.create_script_hook(%{
          name: "Fast Hook",
          command: "echo 'fast' >> #{marker_file}",
          board_id: board.id
        })

      # Attach slow hook first, then fast hook
      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: slow_hook.id,
          position: 0
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: fast_hook.id,
          position: 1
        })

      # Create task in TODO
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      # Start board actor
      start_supervised!({BoardActor, board.id})
      Process.sleep(200)

      # Move task to In Progress (starts slow hook)
      {:ok, moved1} = Task.move(task, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved1)

      # Wait just a bit for the slow hook to start
      Process.sleep(500)

      # Move task to To Review BEFORE slow hook completes (short-circuit)
      {:ok, moved2} = Task.move(moved1, %{column_id: to_review_column.id})
      BoardActor.notify_task_updated(board.id, moved2)

      # Wait for what would have been the slow hook completion
      Process.sleep(4000)

      # The fast hook should NOT have run because the queue was cleared
      # when the task was moved
      if File.exists?(marker_file) do
        content = File.read!(marker_file)
        # Fast hook should not appear
        refute String.contains?(content, "fast")
        File.rm(marker_file)
      end
    end
  end

  describe "hook failure handling" do
    @describetag :integration

    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", user_id: user.id})

      {:ok, columns} = Column.read()
      board_columns = Enum.filter(columns, &(&1.board_id == board.id))
      todo_column = Enum.find(board_columns, &(&1.name == "TODO"))
      in_progress_column = Enum.find(board_columns, &(&1.name == "In Progress"))

      %{
        board: board,
        todo_column: todo_column,
        in_progress_column: in_progress_column,
        user: user
      }
    end

    test "task is set to error state when hook fails", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      # Create a failing hook
      {:ok, failing_hook} =
        Hook.create_script_hook(%{
          name: "Failing Hook",
          command: "exit 1",
          board_id: board.id
        })

      # Attach failing hook to In Progress
      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: failing_hook.id,
          position: 0
        })

      # Create task in TODO
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      # Start board actor
      start_supervised!({BoardActor, board.id})
      Process.sleep(200)

      # Move task to In Progress (will trigger failing hook)
      {:ok, moved_task} = Task.move(task, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved_task)

      # Wait for hook to execute and fail
      Process.sleep(@async_timeout)

      # Reload task and verify error state
      {:ok, updated_task} = Task.get(task.id)

      assert updated_task.agent_status == :error
      assert updated_task.error_message != nil
      assert String.contains?(updated_task.error_message, "Failing Hook")
    end

    test "subsequent hooks do not run after a hook fails", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      marker_file = Path.join(System.tmp_dir!(), "hook_fail_#{System.unique_integer()}")

      # Create a failing hook and a success hook
      {:ok, failing_hook} =
        Hook.create_script_hook(%{
          name: "Failing Hook",
          command: "exit 1",
          board_id: board.id
        })

      {:ok, success_hook} =
        Hook.create_script_hook(%{
          name: "Success Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      # Attach failing hook first (position 0), success hook second (position 1)
      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: failing_hook.id,
          position: 0
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: success_hook.id,
          position: 1
        })

      # Create task in TODO
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      # Start board actor
      start_supervised!({BoardActor, board.id})
      Process.sleep(200)

      # Move task to In Progress
      {:ok, moved_task} = Task.move(task, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved_task)

      # Wait for hooks to process
      Process.sleep(@async_timeout)

      # Success hook should NOT have run because first hook failed
      refute File.exists?(marker_file)
    end
  end

  describe "system hooks" do
    alias Viban.Kanban.SystemHooks.Registry

    test "system hooks are registered" do
      hooks = Registry.all()
      assert is_list(hooks)
      assert length(hooks) > 0

      # Verify Execute AI hook exists
      execute_ai = Enum.find(hooks, &(&1.id == "system:execute-ai"))
      assert execute_ai != nil
      assert execute_ai.name == "Execute AI"
      assert execute_ai.is_system == true
    end

    test "can get system hook by ID" do
      {:ok, hook} = Registry.get("system:execute-ai")

      assert hook.id == "system:execute-ai"
      assert hook.name == "Execute AI"
      assert hook.is_system == true
      assert hook.hook_kind == :system
    end

    test "returns error for unknown system hook" do
      result = Registry.get("system:unknown-hook")

      assert result == {:error, :not_found}
    end

    test "system_hook? correctly identifies system hooks" do
      assert Registry.system_hook?("system:execute-ai")
      assert Registry.system_hook?("system:create-branch")
      refute Registry.system_hook?("some-uuid-hook-id")
      refute Registry.system_hook?(nil)
    end
  end
end
