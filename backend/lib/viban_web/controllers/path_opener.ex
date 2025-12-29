defmodule VibanWeb.PathOpener do
  @moduledoc """
  Shared functionality for opening paths in external applications.

  Provides utilities for:
  - Opening folders in the system file manager
  - Opening paths in code editors

  Used by EditorController and FolderController.
  """

  require Logger

  @doc """
  Opens a folder in the system's file manager.

  Uses the appropriate command for each operating system:
  - macOS: `open`
  - Linux: `xdg-open`
  - Windows: `explorer`

  ## Examples

      iex> PathOpener.open_in_file_manager("/path/to/folder")
      :ok

      iex> PathOpener.open_in_file_manager("/nonexistent")
      {:error, "Failed to open folder"}
  """
  @spec open_in_file_manager(String.t()) :: :ok | {:error, String.t()}
  def open_in_file_manager(path) do
    {cmd, args} = file_manager_command(path)

    Logger.info("[PathOpener] Opening folder #{path} with #{cmd}")

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, code} ->
        Logger.warning("[PathOpener] Failed to open folder (exit code #{code}): #{output}")
        {:error, "Failed to open folder"}
    end
  end

  @doc """
  Opens a path in a code editor.

  Tries editors in order of preference:
  1. Cursor (AI-enhanced VS Code)
  2. VS Code
  3. $EDITOR environment variable

  ## Examples

      iex> PathOpener.open_in_editor("/path/to/project")
      :ok

      iex> PathOpener.open_in_editor("/path/to/project")
      {:error, "No editor found"}
  """
  @spec open_in_editor(String.t()) :: :ok | {:error, String.t()}
  def open_in_editor(path) do
    editors = [
      {"cursor", ["--new-window", path]},
      {"code", ["--new-window", path]},
      {System.get_env("EDITOR", "code"), [path]}
    ]

    Enum.find_value(editors, {:error, "No editor found"}, fn {cmd, args} ->
      if editor_available?(cmd) do
        Logger.info("[PathOpener] Opening #{path} in #{cmd}")

        case System.cmd(cmd, args, stderr_to_stdout: true) do
          {_, 0} ->
            :ok

          {output, _} ->
            Logger.warning("[PathOpener] Editor #{cmd} failed: #{output}")
            nil
        end
      else
        nil
      end
    end)
  end

  @doc """
  Validates a path and resolves it to a directory.

  If the path is a file, returns the parent directory.

  ## Returns

  - `{:ok, dir_path}` - Valid path, returns directory
  - `{:error, :not_found, path}` - Path does not exist
  - `{:error, :access_denied, reason}` - Cannot access path

  ## Examples

      iex> PathOpener.resolve_to_directory("/path/to/folder")
      {:ok, "/path/to/folder"}

      iex> PathOpener.resolve_to_directory("/path/to/file.txt")
      {:ok, "/path/to"}

      iex> PathOpener.resolve_to_directory("/nonexistent")
      {:error, :not_found, "/nonexistent"}
  """
  @spec resolve_to_directory(String.t()) ::
          {:ok, String.t()}
          | {:error, :not_found, String.t()}
          | {:error, :access_denied, String.t()}
  def resolve_to_directory(path) do
    case File.stat(path) do
      {:ok, %{type: :directory}} ->
        {:ok, path}

      {:ok, %{type: :regular}} ->
        {:ok, Path.dirname(path)}

      {:error, :enoent} ->
        {:error, :not_found, path}

      {:error, reason} ->
        {:error, :access_denied, inspect(reason)}
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp file_manager_command(path) do
    case :os.type() do
      {:unix, :darwin} -> {"open", [path]}
      {:unix, _} -> {"xdg-open", [path]}
      {:win32, _} -> {"explorer", [path]}
    end
  end

  defp editor_available?(nil), do: false
  defp editor_available?(""), do: false

  defp editor_available?(cmd) do
    case System.cmd("which", [cmd], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end
end
