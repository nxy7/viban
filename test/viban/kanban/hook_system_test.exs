defmodule Viban.Kanban.HookSystemTest do
  @moduledoc """
  Tests for the hook system including:
  - Hook CRUD operations
  - Column hook assignments
  - execute_once functionality
  - Repository configuration
  """
  use Viban.DataCase, async: false

  alias Viban.Kanban.Board
  alias Viban.Kanban.Column
  alias Viban.Kanban.ColumnHook
  alias Viban.Kanban.Hook
  alias Viban.Kanban.Repository
  alias Viban.Kanban.Task

  describe "Hook resource" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", description: "Test", user_id: user.id})

      # Get the first column (TODO)
      {:ok, columns} = Column.read()
      todo_column = Enum.find(columns, &(&1.board_id == board.id && &1.name == "TODO"))

      {:ok, board: board, todo_column: todo_column, user: user}
    end

    test "can create a script hook", %{board: board} do
      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Test Hook",
          command: "echo 'test'",
          board_id: board.id
        })

      assert hook.name == "Test Hook"
      assert hook.hook_kind == :script
      assert hook.command == "echo 'test'"
      assert hook.board_id == board.id
    end

    test "can create an agent hook", %{board: board} do
      {:ok, hook} =
        Hook.create_agent_hook(%{
          name: "AI Agent Hook",
          agent_prompt: "Fix the code",
          agent_executor: :claude_code,
          agent_auto_approve: true,
          board_id: board.id
        })

      assert hook.name == "AI Agent Hook"
      assert hook.hook_kind == :agent
      assert hook.agent_prompt == "Fix the code"
      assert hook.agent_executor == :claude_code
      assert hook.agent_auto_approve == true
    end

    test "can update a hook", %{board: board} do
      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Test Hook",
          command: "echo 'test'",
          board_id: board.id
        })

      {:ok, updated_hook} =
        Hook.update(hook, %{
          name: "Updated Hook",
          command: "echo 'updated'"
        })

      assert updated_hook.name == "Updated Hook"
      assert updated_hook.command == "echo 'updated'"
    end

    test "can delete a hook", %{board: board} do
      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Test Hook",
          command: "echo 'test'",
          board_id: board.id
        })

      :ok = Hook.destroy(hook)

      {:ok, hooks} = Hook.read()
      assert Enum.find(hooks, &(&1.id == hook.id)) == nil
    end
  end

  describe "ColumnHook resource" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", description: "Test", user_id: user.id})

      {:ok, columns} = Column.read()
      board_columns = Enum.filter(columns, &(&1.board_id == board.id))
      todo_column = Enum.find(board_columns, &(&1.name == "TODO"))
      in_progress_column = Enum.find(board_columns, &(&1.name == "In Progress"))

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Test Hook",
          command: "echo 'test'",
          board_id: board.id
        })

      {:ok, board: board, todo_column: todo_column, in_progress_column: in_progress_column, hook: hook, user: user}
    end

    test "can assign hook to column (only on_entry type supported)", %{
      todo_column: column,
      hook: hook
    } do
      {:ok, column_hook} =
        ColumnHook.create(%{
          column_id: column.id,
          hook_id: hook.id,
          position: 0
        })

      assert column_hook.column_id == column.id
      assert column_hook.hook_id == hook.id
      assert column_hook.hook_type == :on_entry
      assert column_hook.position == 0
    end

    test "can assign same hook to multiple columns", %{
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      hook: hook
    } do
      {:ok, ch1} =
        ColumnHook.create(%{
          column_id: todo_column.id,
          hook_id: hook.id,
          position: 0
        })

      {:ok, ch2} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0
        })

      assert ch1.hook_id == ch2.hook_id
      assert ch1.column_id != ch2.column_id
    end

    test "can set execute_once flag", %{todo_column: column, hook: hook} do
      {:ok, column_hook} =
        ColumnHook.create(%{
          column_id: column.id,
          hook_id: hook.id,
          position: 0,
          execute_once: true
        })

      assert column_hook.execute_once == true
    end

    test "execute_once defaults to false", %{todo_column: column, hook: hook} do
      {:ok, column_hook} =
        ColumnHook.create(%{
          column_id: column.id,
          hook_id: hook.id,
          position: 0
        })

      assert column_hook.execute_once == false
    end

    test "can remove hook from column", %{todo_column: column, hook: hook} do
      {:ok, column_hook} =
        ColumnHook.create(%{
          column_id: column.id,
          hook_id: hook.id,
          position: 0
        })

      :ok = ColumnHook.destroy(column_hook)

      {:ok, column_hooks} = ColumnHook.read()
      assert Enum.find(column_hooks, &(&1.id == column_hook.id)) == nil
    end

    test "multiple hooks on same column have different positions", %{
      todo_column: column,
      hook: hook1,
      board: board
    } do
      {:ok, hook2} =
        Hook.create_script_hook(%{
          name: "Hook 2",
          command: "echo 'hook 2'",
          board_id: board.id
        })

      {:ok, ch1} =
        ColumnHook.create(%{
          column_id: column.id,
          hook_id: hook1.id,
          position: 0
        })

      {:ok, ch2} =
        ColumnHook.create(%{
          column_id: column.id,
          hook_id: hook2.id,
          position: 1
        })

      assert ch1.position == 0
      assert ch2.position == 1
    end
  end

  describe "Repository resource" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", description: "Test", user_id: user.id})
      {:ok, board: board, user: user}
    end

    test "can create a repository", %{board: board} do
      {:ok, repo} =
        Repository.create(%{
          name: "Test Repo",
          provider: :github,
          provider_repo_id: "123456",
          full_name: "test-user/test-repo",
          clone_url: "https://github.com/test-user/test-repo.git",
          default_branch: "main",
          board_id: board.id
        })

      assert repo.name == "Test Repo"
      assert repo.provider == :github
      assert repo.clone_url == "https://github.com/test-user/test-repo.git"
      assert repo.default_branch == "main"
      assert repo.board_id == board.id
    end

    test "can update a repository", %{board: board} do
      {:ok, repo} =
        Repository.create(%{
          name: "Test Repo",
          provider: :github,
          provider_repo_id: "123456",
          full_name: "test-user/test-repo",
          clone_url: "https://github.com/test-user/test-repo.git",
          board_id: board.id
        })

      {:ok, updated_repo} =
        Repository.update(repo, %{
          name: "Updated Repo",
          default_branch: "develop"
        })

      assert updated_repo.name == "Updated Repo"
      assert updated_repo.default_branch == "develop"
    end

    test "can delete a repository", %{board: board} do
      {:ok, repo} =
        Repository.create(%{
          name: "Test Repo",
          provider: :github,
          provider_repo_id: "123456",
          full_name: "test-user/test-repo",
          clone_url: "https://github.com/test-user/test-repo.git",
          board_id: board.id
        })

      :ok = Repository.destroy(repo)

      {:ok, repos} = Repository.read()
      assert Enum.find(repos, &(&1.id == repo.id)) == nil
    end
  end

  describe "Task worktree fields" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", description: "Test", user_id: user.id})

      {:ok, columns} = Column.read()
      todo_column = Enum.find(columns, &(&1.board_id == board.id && &1.name == "TODO"))

      {:ok, board: board, todo_column: todo_column, user: user}
    end

    test "task starts without worktree info", %{todo_column: column} do
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: column.id
        })

      assert task.worktree_path == nil
      assert task.worktree_branch == nil
    end

    test "can assign worktree to task", %{todo_column: column} do
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: column.id
        })

      {:ok, updated_task} =
        Task.assign_worktree(task, %{
          worktree_path: "/tmp/worktrees/test-task",
          worktree_branch: "task/test"
        })

      assert updated_task.worktree_path == "/tmp/worktrees/test-task"
      assert updated_task.worktree_branch == "task/test"
    end
  end

  describe "Task executed_hooks tracking" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", description: "Test", user_id: user.id})

      {:ok, columns} = Column.read()
      todo_column = Enum.find(columns, &(&1.board_id == board.id && &1.name == "TODO"))

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Test Hook",
          command: "echo 'test'",
          board_id: board.id
        })

      {:ok, column_hook} =
        ColumnHook.create(%{
          column_id: todo_column.id,
          hook_id: hook.id,
          position: 0,
          execute_once: true
        })

      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      {:ok, board: board, todo_column: todo_column, hook: hook, column_hook: column_hook, task: task, user: user}
    end

    test "task starts with empty executed_hooks", %{task: task} do
      assert task.executed_hooks == []
    end

    test "can mark a hook as executed", %{task: task, column_hook: column_hook} do
      {:ok, updated_task} = Task.mark_hook_executed(task, column_hook.id)

      assert column_hook.id in updated_task.executed_hooks
    end

    test "can mark multiple hooks as executed", %{
      task: task,
      column_hook: column_hook1,
      board: board,
      todo_column: column
    } do
      {:ok, hook2} =
        Hook.create_script_hook(%{
          name: "Hook 2",
          command: "echo 'hook 2'",
          board_id: board.id
        })

      {:ok, column_hook2} =
        ColumnHook.create(%{
          column_id: column.id,
          hook_id: hook2.id,
          position: 1,
          execute_once: true
        })

      {:ok, task1} = Task.mark_hook_executed(task, column_hook1.id)
      {:ok, task2} = Task.mark_hook_executed(task1, column_hook2.id)

      assert column_hook1.id in task2.executed_hooks
      assert column_hook2.id in task2.executed_hooks
    end
  end
end
