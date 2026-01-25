defmodule Viban.Executors.HookExecutor do
  @moduledoc """
  Specialized executor for running agent hooks.
  Unlike the main Runner, this doesn't manage interactive sessions
  but runs a single prompt to completion.
  """

  require Logger

  @doc """
  Run an agent hook with a prompt.
  Returns {:ok, output} or {:error, reason}

  Runs until completion without timeout - users can manually cancel if needed.
  """
  def run(task, prompt, executor_type, opts \\ []) do
    working_dir = Keyword.get(opts, :working_directory, task.worktree_path || File.cwd!())
    auto_approve = Keyword.get(opts, :auto_approve, false)

    # Build the command based on executor type
    case build_command(executor_type, prompt, working_dir, auto_approve) do
      {:ok, {executable, args}} ->
        Logger.info("[HookExecutor] Executing hook with #{executor_type} in #{working_dir}")
        Logger.debug("[HookExecutor] Prompt: #{String.slice(prompt, 0, 200)}...")

        port =
          Port.open({:spawn_executable, executable}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            {:cd, working_dir},
            {:args, args}
          ])

        case collect_output(port, "") do
          {:ok, output} ->
            Logger.info("[HookExecutor] Hook completed successfully")
            {:ok, output}

          {:error, reason} ->
            Logger.error("[HookExecutor] Hook failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Build the full prompt with task context for an agent hook.
  """
  def build_agent_prompt(base_prompt, task, column_name \\ nil) do
    column = column_name || "Unknown"

    """
    You are executing an automated hook for a task. Here is the context:

    ## Task Information
    - **Title**: #{task.title}
    - **Description**: #{task.description || "(No description)"}
    - **Column**: #{column}
    - **Worktree Path**: #{task.worktree_path || "N/A"}

    ## Your Instructions
    #{base_prompt}

    ## Important Notes
    - This is an automated hook execution, not an interactive session
    - Complete the task efficiently and report your actions
    - If you cannot complete the task, clearly explain why
    """
  end

  # Build command based on executor type
  defp build_command(:claude_code, prompt, _working_dir, auto_approve) do
    case System.find_executable("claude") do
      nil ->
        {:error, "Claude CLI not found in PATH"}

      executable ->
        args = ["--print", "--output-format", "text"]
        args = if auto_approve, do: args ++ ["--dangerously-skip-permissions"], else: args
        args = args ++ ["--prompt", prompt]
        {:ok, {executable, args}}
    end
  end

  defp build_command(:gemini_cli, prompt, _working_dir, _auto_approve) do
    case System.find_executable("gemini") do
      nil -> {:error, "Gemini CLI not found in PATH"}
      executable -> {:ok, {executable, ["--prompt", prompt]}}
    end
  end

  defp build_command(:codex, prompt, _working_dir, auto_approve) do
    case System.find_executable("codex") do
      nil ->
        {:error, "Codex not found in PATH"}

      executable ->
        args = if auto_approve, do: ["--auto-approve"], else: []
        args = args ++ [prompt]
        {:ok, {executable, args}}
    end
  end

  defp build_command(:opencode, prompt, _working_dir, _auto_approve) do
    case System.find_executable("opencode") do
      nil -> {:error, "OpenCode not found in PATH"}
      executable -> {:ok, {executable, ["--prompt", prompt]}}
    end
  end

  defp build_command(:cursor_agent, prompt, _working_dir, _auto_approve) do
    case System.find_executable("cursor") do
      nil -> {:error, "Cursor not found in PATH"}
      executable -> {:ok, {executable, ["--prompt", prompt]}}
    end
  end

  defp build_command(unknown, _prompt, _working_dir, _auto_approve) do
    {:error, "Unknown executor type: #{inspect(unknown)}"}
  end

  # Collect output from port until exit
  defp collect_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        collect_output(port, acc <> data)

      {^port, {:exit_status, 0}} ->
        {:ok, acc}

      {^port, {:exit_status, status}} ->
        {:error, {:exit_status, status, acc}}
    end
  end
end
