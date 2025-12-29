defmodule Viban.Kanban.SystemHooks.RunTestsHook do
  @moduledoc """
  System hook that automatically runs the project's test suite.

  Detects the project type based on configuration files and runs the
  appropriate test command.

  ## Supported Project Types

  | Project Type | Detection File    | Command                |
  |--------------|-------------------|------------------------|
  | Elixir       | `mix.exs`         | `mix test`             |
  | Node.js      | `package.json`    | `npm test`             |
  | Python (pytest.ini) | `pytest.ini` | `pytest`            |
  | Python (setup.py)   | `setup.py`   | `python -m pytest`     |
  | Rust         | `Cargo.toml`      | `cargo test`           |
  | Go           | `go.mod`          | `go test ./...`        |
  | Generic      | `Makefile`        | `make test`            |

  ## Usage

  This hook is typically attached to columns like "QA" or "Testing"
  to ensure tests pass before tasks move to completion.

  ## Timeout

  Default timeout is 5 minutes (300,000ms) to accommodate large test suites.
  """

  use Viban.Kanban.SystemHooks.ShellHook,
    id: "system:run-tests",
    name: "Run Test Suite",
    description:
      "Automatically runs the project's test suite when a task enters this column. " <>
        "Detects and runs the appropriate test command (mix test, npm test, pytest, etc.)",
    timeout_ms: 300_000

  # ---------------------------------------------------------------------------
  # Constants - Project Detection Markers
  # ---------------------------------------------------------------------------

  @elixir_marker "mix.exs"
  @node_marker "package.json"
  @pytest_marker "pytest.ini"
  @python_setup_marker "setup.py"
  @rust_marker "Cargo.toml"
  @go_marker "go.mod"
  @make_marker "Makefile"

  # ---------------------------------------------------------------------------
  # Constants - Test Commands
  # ---------------------------------------------------------------------------

  @elixir_test_cmd "mix test"
  @node_test_cmd "npm test"
  @pytest_cmd "pytest"
  @python_pytest_cmd "python -m pytest"
  @rust_test_cmd "cargo test"
  @go_test_cmd "go test ./..."
  @make_test_cmd "make test"
  @fallback_cmd "echo 'No test runner detected'"

  # ---------------------------------------------------------------------------
  # ShellHook Callback
  # ---------------------------------------------------------------------------

  @impl Viban.Kanban.SystemHooks.ShellHook
  @doc """
  Detects and returns the appropriate test command for the project type.

  Checks for project configuration files in the worktree path and returns
  the corresponding test runner command.
  """
  @spec detect_command(String.t()) :: String.t()
  def detect_command(worktree_path) do
    cond do
      elixir_project?(worktree_path) -> @elixir_test_cmd
      node_project?(worktree_path) -> @node_test_cmd
      pytest_project?(worktree_path) -> @pytest_cmd
      python_setup_project?(worktree_path) -> @python_pytest_cmd
      rust_project?(worktree_path) -> @rust_test_cmd
      go_project?(worktree_path) -> @go_test_cmd
      make_project?(worktree_path) -> @make_test_cmd
      true -> @fallback_cmd
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Project Detection
  # ---------------------------------------------------------------------------

  @spec elixir_project?(String.t()) :: boolean()
  defp elixir_project?(path), do: file_exists?(path, @elixir_marker)

  @spec node_project?(String.t()) :: boolean()
  defp node_project?(path), do: file_exists?(path, @node_marker)

  @spec pytest_project?(String.t()) :: boolean()
  defp pytest_project?(path), do: file_exists?(path, @pytest_marker)

  @spec python_setup_project?(String.t()) :: boolean()
  defp python_setup_project?(path), do: file_exists?(path, @python_setup_marker)

  @spec rust_project?(String.t()) :: boolean()
  defp rust_project?(path), do: file_exists?(path, @rust_marker)

  @spec go_project?(String.t()) :: boolean()
  defp go_project?(path), do: file_exists?(path, @go_marker)

  @spec make_project?(String.t()) :: boolean()
  defp make_project?(path), do: file_exists?(path, @make_marker)

  @spec file_exists?(String.t(), String.t()) :: boolean()
  defp file_exists?(base_path, filename) do
    File.exists?(Path.join(base_path, filename))
  end
end
