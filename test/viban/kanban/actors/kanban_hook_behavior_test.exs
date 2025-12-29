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

  alias Viban.Kanban.Actors.BoardSupervisor
  alias Viban.Kanban.Actors.CommandQueue
  alias Viban.Kanban.ColumnHook
  alias Viban.Kanban.Hook
  alias Viban.Kanban.Task

  @moduletag :unit

  @async_timeout 2000

  # ============================================================================
  # Tests
  # ============================================================================

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
      create_board_with_columns()
    end

    test "hook runs when task enters column", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      alias Viban.Kanban.HookExecution

      marker_file = temp_file_with_cleanup("hook_executed")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Marker Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0
        })

      {:ok, all_hooks} = ColumnHook.read()
      ip_hooks = Enum.filter(all_hooks, &(&1.column_id == in_progress_column.id))
      assert length(ip_hooks) == 1, "Expected 1 hook on In Progress, got #{length(ip_hooks)}"
      assert hd(ip_hooks).id == column_hook.id

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})

      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(500)

      {:ok, all_executions} = HookExecution.history_for_task(task.id)
      assert all_executions != [], "No hook executions created for task"

      Process.sleep(@async_timeout)

      assert File.exists?(marker_file),
             "Hook did not execute - marker file not found at #{marker_file}"
    end

    test "hooks execute in position order", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      marker_file = temp_file_with_cleanup("hook_order")

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

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(@async_timeout * 2)

      assert File.exists?(marker_file)
      content = File.read!(marker_file)
      lines = String.split(content, "\n", trim: true)

      assert lines == ["first", "second", "third"]
    end
  end

  describe "execute_once flag behavior" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "execute_once=true hook only runs once per task", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      counter_file = temp_file_with_cleanup("hook_counter")
      File.write!(counter_file, "0")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Counter Hook",
          command: "expr $(cat #{counter_file}) + 1 > #{counter_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0,
          execute_once: true
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, moved1} = Task.move(task, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "1"

      {:ok, moved2} = Task.move(moved1, %{column_id: todo_column.id})
      Process.sleep(500)

      {:ok, _moved3} = Task.move(moved2, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "1"
    end

    test "execute_once=false hook runs every time task enters column", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      counter_file = temp_file_with_cleanup("hook_counter")
      File.write!(counter_file, "0")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Counter Hook",
          command: "expr $(cat #{counter_file}) + 1 > #{counter_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0,
          execute_once: false
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, moved1} = Task.move(task, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "1"

      {:ok, moved2} = Task.move(moved1, %{column_id: todo_column.id})
      Process.sleep(500)

      {:ok, _moved3} = Task.move(moved2, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "2"
    end
  end

  describe "hook short-circuiting" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "moving task clears remaining hook queue", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      to_review_column: to_review_column
    } do
      marker_file = temp_file_with_cleanup("shortcircuit")

      {:ok, slow_hook} =
        Hook.create_script_hook(%{
          name: "Slow Hook",
          command: "sleep 3 && echo 'slow' >> #{marker_file}",
          board_id: board.id
        })

      {:ok, fast_hook} =
        Hook.create_script_hook(%{
          name: "Fast Hook",
          command: "echo 'fast' >> #{marker_file}",
          board_id: board.id
        })

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

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, moved1} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(500)

      {:ok, _moved2} = Task.move(moved1, %{column_id: to_review_column.id})

      Process.sleep(4000)

      if File.exists?(marker_file) do
        content = File.read!(marker_file)
        refute String.contains?(content, "fast")
      end
    end
  end

  describe "hook failure handling" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "task is set to error state when hook fails", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      {:ok, failing_hook} =
        Hook.create_script_hook(%{
          name: "Failing Hook",
          command: "exit 1",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: failing_hook.id,
          position: 0
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(@async_timeout)

      {:ok, updated_task} = Task.get(task.id)

      assert updated_task.agent_status == :error
      assert updated_task.error_message
      assert String.contains?(updated_task.error_message, "Failing Hook")
    end

    test "subsequent hooks do not run after a hook fails", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      marker_file = temp_file_with_cleanup("hook_fail")

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

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(@async_timeout)

      refute File.exists?(marker_file)
    end
  end

  describe "system hooks" do
    alias Viban.Kanban.SystemHooks.Registry

    test "system hooks are registered" do
      hooks = Registry.all()
      assert is_list(hooks)
      assert hooks != []

      # Verify Execute AI hook exists
      execute_ai = Enum.find(hooks, &(&1.id == "system:execute-ai"))
      assert execute_ai
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
