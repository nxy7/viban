defmodule Viban.Kanban.Actors.HookRunnerTest do
  @moduledoc """
  Tests for the HookRunner module that executes shell commands.

  Note: The hook system was simplified to only support on_entry hooks
  and always executes in the task's worktree directory.
  """
  use ExUnit.Case, async: true

  alias Viban.Kanban.Actors.HookRunner

  # Create a mock hook struct for testing (without hook_kind - legacy)
  defmodule MockHook do
    @moduledoc false
    defstruct [:name, :command]
  end

  # Create a mock hook struct with hook_kind field (matches real Hook struct)
  defmodule MockHookWithKind do
    @moduledoc false
    defstruct [:name, :command, :hook_kind, :agent_prompt, :agent_executor, :agent_auto_approve]
  end

  # Create a mock task struct for testing
  defmodule MockTask do
    @moduledoc false
    defstruct [:id, :worktree_path, :title, :description, :column_id]
  end

  describe "execute/4" do
    test "executes script hook with struct containing hook_kind" do
      hook = %MockHookWithKind{
        name: "Script Hook",
        command: "echo 'executed'",
        hook_kind: :script
      }

      task = %MockTask{
        id: "test-task-id",
        worktree_path: System.tmp_dir!(),
        title: "Test Task"
      }

      result = HookRunner.execute(hook, task, nil, [])

      assert {:ok, output} = result
      assert String.contains?(output, "executed")
    end

    test "executes hook with nil hook_kind (defaults to script behavior)" do
      hook = %MockHookWithKind{
        name: "Default Hook",
        command: "echo 'default behavior'",
        hook_kind: nil
      }

      task = %MockTask{
        id: "test-task-id",
        worktree_path: System.tmp_dir!(),
        title: "Test Task"
      }

      result = HookRunner.execute(hook, task, nil, [])

      assert {:ok, output} = result
      assert String.contains?(output, "default behavior")
    end

    test "handles struct without hook_kind field (backward compatibility)" do
      # This tests that we don't crash when hook_kind field is missing
      hook = %MockHook{
        name: "Legacy Hook",
        command: "echo 'legacy'"
      }

      task = %MockTask{
        id: "test-task-id",
        worktree_path: System.tmp_dir!(),
        title: "Test Task"
      }

      result = HookRunner.execute(hook, task, nil, [])

      assert {:ok, output} = result
      assert String.contains?(output, "legacy")
    end

    test "skips execution when worktree_path is nil" do
      hook = %MockHookWithKind{
        name: "Skip Hook",
        command: "echo 'should not run'",
        hook_kind: :script
      }

      task = %MockTask{
        id: "test-task-id",
        worktree_path: nil,
        title: "Test Task"
      }

      result = HookRunner.execute(hook, task, nil, [])

      assert {:ok, :skipped} = result
    end
  end

  describe "run_once/2" do
    test "executes command successfully" do
      hook = %MockHook{
        name: "Echo Test",
        command: "echo 'hello world'"
      }

      result = HookRunner.run_once(hook, System.tmp_dir!())

      assert {:ok, output} = result
      assert String.contains?(output, "hello world")
    end

    test "returns error for failed command" do
      hook = %MockHook{
        name: "Fail Test",
        command: "exit 1"
      }

      result = HookRunner.run_once(hook, System.tmp_dir!())

      assert {:error, {:exit_code, 1, _}} = result
    end

    test "skips when working directory is nil" do
      hook = %MockHook{
        name: "Skip Test",
        command: "echo 'test'"
      }

      result = HookRunner.run_once(hook, nil)

      assert {:ok, :skipped} = result
    end

    test "skips when working directory does not exist" do
      hook = %MockHook{
        name: "Skip Test",
        command: "echo 'test'"
      }

      result = HookRunner.run_once(hook, "/nonexistent/path")

      assert {:ok, :skipped} = result
    end
  end
end
