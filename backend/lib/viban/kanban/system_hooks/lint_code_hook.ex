defmodule Viban.Kanban.SystemHooks.LintCodeHook do
  @moduledoc """
  System hook that runs code linting and formatting checks.

  Automatically detects the project type based on configuration files
  and runs the appropriate linter/formatter command.

  ## Supported Project Types

  | Project Type       | Detection File(s)                              | Command                    |
  |--------------------|------------------------------------------------|----------------------------|
  | Elixir             | `mix.exs`                                      | `mix format --check-formatted` |
  | JavaScript/TypeScript | `.eslintrc.json`, `.eslintrc.js`, `eslint.config.js` | `npx eslint .`       |
  | Python (Ruff)      | `pyproject.toml`                               | `ruff check .`             |
  | Python (Flake8)    | `.flake8`                                      | `flake8 .`                 |
  | Rust               | `Cargo.toml`                                   | `cargo clippy`             |
  | Go                 | `go.mod`                                       | `go vet ./...`             |

  ## Usage

  This hook is typically attached to columns like "Code Review" or "QA"
  to ensure code quality before tasks move forward.

  ## Timeout

  Default timeout is 60 seconds, which should be sufficient for most
  linting operations.
  """

  use Viban.Kanban.SystemHooks.ShellHook,
    id: "system:lint-code",
    name: "Lint & Format Code",
    description:
      "Runs code linting and formatting checks. " <>
        "Detects the project type and runs appropriate linters (mix format, eslint, etc.)",
    timeout_ms: 60_000

  # ---------------------------------------------------------------------------
  # Constants - Project Detection
  # ---------------------------------------------------------------------------

  @elixir_marker "mix.exs"
  @python_ruff_marker "pyproject.toml"
  @python_flake8_marker ".flake8"
  @rust_marker "Cargo.toml"
  @go_marker "go.mod"

  @eslint_config_files [".eslintrc.json", ".eslintrc.js", "eslint.config.js"]

  # ---------------------------------------------------------------------------
  # Constants - Lint Commands
  # ---------------------------------------------------------------------------

  @elixir_lint_cmd "mix format --check-formatted"
  @eslint_cmd "npx eslint ."
  @ruff_cmd "ruff check ."
  @flake8_cmd "flake8 ."
  @clippy_cmd "cargo clippy"
  @go_vet_cmd "go vet ./..."
  @fallback_cmd "echo 'No linter detected'"

  # ---------------------------------------------------------------------------
  # ShellHook Callback
  # ---------------------------------------------------------------------------

  @impl Viban.Kanban.SystemHooks.ShellHook
  @doc """
  Detects and returns the appropriate lint command for the project type.

  Checks for project configuration files in the worktree path and returns
  the corresponding linter command.
  """
  @spec detect_command(String.t()) :: String.t()
  def detect_command(worktree_path) do
    cond do
      elixir_project?(worktree_path) -> @elixir_lint_cmd
      eslint_project?(worktree_path) -> @eslint_cmd
      ruff_project?(worktree_path) -> @ruff_cmd
      flake8_project?(worktree_path) -> @flake8_cmd
      rust_project?(worktree_path) -> @clippy_cmd
      go_project?(worktree_path) -> @go_vet_cmd
      true -> @fallback_cmd
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Project Detection
  # ---------------------------------------------------------------------------

  @spec elixir_project?(String.t()) :: boolean()
  defp elixir_project?(path), do: file_exists?(path, @elixir_marker)

  @spec eslint_project?(String.t()) :: boolean()
  defp eslint_project?(path) do
    Enum.any?(@eslint_config_files, &file_exists?(path, &1))
  end

  @spec ruff_project?(String.t()) :: boolean()
  defp ruff_project?(path), do: file_exists?(path, @python_ruff_marker)

  @spec flake8_project?(String.t()) :: boolean()
  defp flake8_project?(path), do: file_exists?(path, @python_flake8_marker)

  @spec rust_project?(String.t()) :: boolean()
  defp rust_project?(path), do: file_exists?(path, @rust_marker)

  @spec go_project?(String.t()) :: boolean()
  defp go_project?(path), do: file_exists?(path, @go_marker)

  @spec file_exists?(String.t(), String.t()) :: boolean()
  defp file_exists?(base_path, filename) do
    File.exists?(Path.join(base_path, filename))
  end
end
