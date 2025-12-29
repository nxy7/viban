# Feature: Pull Request Support

## Overview

Add initial PR support to allow users to create PRs from tasks and view existing PRs. The system should detect PRs created outside of the app (e.g., by the LLM agent directly via `gh pr create`).

## User Stories

1. **Create PR**: As a user, I can click a button to create a PR for a task that has code changes.
2. **View PR**: As a user, I can click a button to view the PR on GitHub when one exists.
3. **Auto-detect PR**: As a user, I see the "View PR" button even if the PR was created outside our system (by the agent or manually).
4. **PR Status**: As a user, I can see the current PR status (open, merged, closed).

## Technical Design

### Data Model

Add PR tracking to tasks:

```elixir
# backend/lib/viban/kanban/task.ex

defmodule Viban.Kanban.Task do
  use Ash.Resource,
    otp_app: :viban,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Existing fields...
    attribute :title, :string, allow_nil?: false
    attribute :description, :string
    attribute :status, :atom

    # New: PR information
    attribute :pr_url, :string do
      description "URL to the pull request"
    end

    attribute :pr_number, :integer do
      description "PR number in the repository"
    end

    attribute :pr_status, :atom do
      constraints [one_of: [:open, :merged, :closed, :draft]]
      description "Current status of the PR"
    end

    attribute :branch_name, :string do
      description "Git branch associated with this task"
    end

    timestamps()
  end

  actions do
    # ... existing actions ...

    update :link_pr do
      accept []
      argument :pr_url, :string, allow_nil?: false
      argument :pr_number, :integer, allow_nil?: false
      argument :pr_status, :atom, allow_nil?: false

      change set_attribute(:pr_url, arg(:pr_url))
      change set_attribute(:pr_number, arg(:pr_number))
      change set_attribute(:pr_status, arg(:pr_status))
    end

    update :update_pr_status do
      accept [:pr_status]
    end

    update :set_branch do
      accept [:branch_name]
    end
  end
end
```

### Database Migration

```elixir
# backend/priv/repo/migrations/YYYYMMDDHHMMSS_add_pr_fields_to_tasks.exs

defmodule Viban.Repo.Migrations.AddPrFieldsToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :pr_url, :string
      add :pr_number, :integer
      add :pr_status, :string
      add :branch_name, :string
    end

    create index(:tasks, [:branch_name])
    create index(:tasks, [:pr_number])
  end
end
```

### GitHub Integration Service

```elixir
# backend/lib/viban/github/client.ex

defmodule Viban.GitHub.Client do
  @moduledoc """
  GitHub API client for PR operations.
  """

  @doc """
  Create a pull request.
  """
  def create_pr(repo, base_branch, head_branch, title, body) do
    # Use GitHub API or gh CLI
    case System.cmd("gh", [
      "pr", "create",
      "--repo", repo,
      "--base", base_branch,
      "--head", head_branch,
      "--title", title,
      "--body", body
    ]) do
      {output, 0} ->
        # Parse PR URL from output
        pr_url = String.trim(output)
        pr_number = extract_pr_number(pr_url)
        {:ok, %{url: pr_url, number: pr_number, status: :open}}

      {error, _} ->
        {:error, error}
    end
  end

  @doc """
  Find existing PR for a branch.
  """
  def find_pr_for_branch(repo, branch_name) do
    case System.cmd("gh", [
      "pr", "list",
      "--repo", repo,
      "--head", branch_name,
      "--json", "number,url,state,isDraft",
      "--limit", "1"
    ]) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, [pr | _]} ->
            {:ok, %{
              url: pr["url"],
              number: pr["number"],
              status: parse_pr_status(pr["state"], pr["isDraft"])
            }}
          {:ok, []} ->
            {:ok, nil}
          _ ->
            {:error, "Failed to parse PR data"}
        end

      {error, _} ->
        {:error, error}
    end
  end

  @doc """
  Get PR status by number.
  """
  def get_pr_status(repo, pr_number) do
    case System.cmd("gh", [
      "pr", "view", to_string(pr_number),
      "--repo", repo,
      "--json", "state,isDraft,merged"
    ]) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, pr} ->
            {:ok, parse_pr_status(pr["state"], pr["isDraft"], pr["merged"])}
          _ ->
            {:error, "Failed to parse PR status"}
        end

      {error, _} ->
        {:error, error}
    end
  end

  defp extract_pr_number(url) do
    case Regex.run(~r/\/pull\/(\d+)/, url) do
      [_, number] -> String.to_integer(number)
      _ -> nil
    end
  end

  defp parse_pr_status(state, is_draft, merged \\ false) do
    cond do
      merged -> :merged
      is_draft -> :draft
      state == "OPEN" -> :open
      state == "CLOSED" -> :closed
      state == "MERGED" -> :merged
      true -> :open
    end
  end
end
```

### PR Detection Service

Automatically detect PRs created by agents or externally:

```elixir
# backend/lib/viban/github/pr_detector.ex

defmodule Viban.GitHub.PRDetector do
  @moduledoc """
  Detects PRs created outside of the system.
  """

  alias Viban.GitHub.Client
  alias Viban.Kanban

  @doc """
  Check if a PR exists for a task's branch and link it.
  Called periodically or after task execution completes.
  """
  def detect_and_link_pr(task) do
    with {:ok, branch} when not is_nil(branch) <- {:ok, task.branch_name},
         {:ok, repo} <- get_repo_for_task(task),
         {:ok, pr} when not is_nil(pr) <- Client.find_pr_for_branch(repo, branch) do
      # Link the PR to the task
      Kanban.link_pr(task, pr.url, pr.number, pr.status)
    else
      _ -> {:ok, :no_pr_found}
    end
  end

  @doc """
  Sync PR status for all tasks with linked PRs.
  """
  def sync_all_pr_statuses do
    Kanban.list_tasks_with_prs()
    |> Enum.each(&sync_pr_status/1)
  end

  defp sync_pr_status(task) do
    with {:ok, repo} <- get_repo_for_task(task),
         {:ok, status} <- Client.get_pr_status(repo, task.pr_number) do
      if status != task.pr_status do
        Kanban.update_pr_status(task, status)
      end
    end
  end

  defp get_repo_for_task(task) do
    # Get repo from task's board/project configuration
    {:ok, task.column.board.repo_full_name}
  end
end
```

### Branch Name Tracking

Capture branch name when agent creates it:

```elixir
# backend/lib/viban/agents/output_parser.ex

defmodule Viban.Agents.OutputParser do
  # ... existing code ...

  @doc """
  Extract branch name from agent output.
  Agents typically output "git checkout -b <branch>" or similar.
  """
  def extract_branch_name(output) do
    patterns = [
      ~r/git checkout -b ([^\s]+)/,
      ~r/git switch -c ([^\s]+)/,
      ~r/Created branch '([^']+)'/,
      ~r/Switched to.*branch '([^']+)'/
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, output) do
        [_, branch] -> branch
        _ -> nil
      end
    end)
  end

  @doc """
  Extract PR URL from agent output.
  Agents using `gh pr create` will output the PR URL.
  """
  def extract_pr_url(output) do
    case Regex.run(~r|(https://github\.com/[^/]+/[^/]+/pull/\d+)|, output) do
      [_, url] -> url
      _ -> nil
    end
  end
end
```

### Frontend Components

#### PR Button Component

```tsx
// frontend/src/components/PRButton.tsx

import { Show, createSignal } from "solid-js";

interface Props {
  task: Task;
  onCreatePR: () => Promise<void>;
}

export function PRButton(props: Props) {
  const [isCreating, setIsCreating] = createSignal(false);

  const hasPR = () => !!props.task.pr_url;
  const canCreatePR = () => !!props.task.branch_name && !hasPR();

  const handleCreatePR = async () => {
    setIsCreating(true);
    try {
      await props.onCreatePR();
    } finally {
      setIsCreating(false);
    }
  };

  const statusColor = () => {
    switch (props.task.pr_status) {
      case "open": return "text-green-400 bg-green-500/20";
      case "draft": return "text-zinc-400 bg-zinc-500/20";
      case "merged": return "text-purple-400 bg-purple-500/20";
      case "closed": return "text-red-400 bg-red-500/20";
      default: return "text-zinc-400 bg-zinc-500/20";
    }
  };

  return (
    <div class="flex items-center gap-2">
      {/* View PR button - shown when PR exists */}
      <Show when={hasPR()}>
        <a
          href={props.task.pr_url}
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex items-center gap-2 px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700
                 rounded-md text-sm transition-colors"
        >
          <GitPullRequestIcon class="w-4 h-4" />
          <span>View PR</span>
          <span class={`text-xs px-1.5 py-0.5 rounded ${statusColor()}`}>
            #{props.task.pr_number}
          </span>
        </a>
      </Show>

      {/* Create PR button - shown when branch exists but no PR */}
      <Show when={canCreatePR()}>
        <button
          onClick={handleCreatePR}
          disabled={isCreating()}
          class="inline-flex items-center gap-2 px-3 py-1.5 bg-green-600 hover:bg-green-700
                 disabled:opacity-50 rounded-md text-sm transition-colors"
        >
          <Show when={isCreating()} fallback={<GitPullRequestIcon class="w-4 h-4" />}>
            <SpinnerIcon class="w-4 h-4 animate-spin" />
          </Show>
          <span>{isCreating() ? "Creating..." : "Create PR"}</span>
        </button>
      </Show>

      {/* No branch indicator */}
      <Show when={!props.task.branch_name && !hasPR()}>
        <span class="text-xs text-zinc-500">No branch yet</span>
      </Show>
    </div>
  );
}
```

#### PR Status Badge

```tsx
// frontend/src/components/PRStatusBadge.tsx

interface Props {
  status: "open" | "draft" | "merged" | "closed";
  prNumber: number;
}

export function PRStatusBadge(props: Props) {
  const config = () => {
    switch (props.status) {
      case "open":
        return {
          icon: GitPullRequestIcon,
          color: "text-green-400 bg-green-500/20 border-green-500/30",
          label: "Open"
        };
      case "draft":
        return {
          icon: GitPullRequestDraftIcon,
          color: "text-zinc-400 bg-zinc-500/20 border-zinc-500/30",
          label: "Draft"
        };
      case "merged":
        return {
          icon: GitMergeIcon,
          color: "text-purple-400 bg-purple-500/20 border-purple-500/30",
          label: "Merged"
        };
      case "closed":
        return {
          icon: GitPullRequestClosedIcon,
          color: "text-red-400 bg-red-500/20 border-red-500/30",
          label: "Closed"
        };
    }
  };

  const Icon = config().icon;

  return (
    <span class={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs
                  border ${config().color}`}>
      <Icon class="w-3 h-3" />
      <span>#{props.prNumber}</span>
      <span class="opacity-75">{config().label}</span>
    </span>
  );
}
```

#### Integration in Task Card

```tsx
// frontend/src/components/TaskCard.tsx

export function TaskCard(props: { task: Task }) {
  return (
    <div class="...">
      {/* Task title and content */}
      <h4 class="font-medium">{props.task.title}</h4>

      {/* PR indicator on card */}
      <Show when={props.task.pr_url}>
        <div class="mt-2">
          <PRStatusBadge
            status={props.task.pr_status}
            prNumber={props.task.pr_number}
          />
        </div>
      </Show>

      {/* Branch indicator if no PR yet */}
      <Show when={props.task.branch_name && !props.task.pr_url}>
        <div class="mt-2 flex items-center gap-1 text-xs text-zinc-500">
          <GitBranchIcon class="w-3 h-3" />
          <span class="truncate max-w-32">{props.task.branch_name}</span>
        </div>
      </Show>
    </div>
  );
}
```

#### PR Section in Card Details

```tsx
// frontend/src/components/CardDetailsSidePanel.tsx

export function CardDetailsSidePanel(props: Props) {
  const createPR = async () => {
    await api.createPRForTask(props.task.id);
  };

  return (
    <div class="...">
      {/* ... other sections ... */}

      {/* PR Section */}
      <div class="border-t border-zinc-700 pt-4 mt-4">
        <h3 class="text-sm font-medium text-zinc-400 mb-2">Pull Request</h3>
        <PRButton task={task()} onCreatePR={createPR} />

        {/* PR Details when exists */}
        <Show when={task().pr_url}>
          <div class="mt-3 p-3 bg-zinc-800/50 rounded-lg space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-sm text-zinc-400">Status</span>
              <PRStatusBadge
                status={task().pr_status}
                prNumber={task().pr_number}
              />
            </div>
            <div class="flex items-center justify-between">
              <span class="text-sm text-zinc-400">Branch</span>
              <code class="text-xs bg-zinc-900 px-2 py-0.5 rounded">
                {task().branch_name}
              </code>
            </div>
          </div>
        </Show>
      </div>
    </div>
  );
}
```

### API Endpoints

```elixir
# backend/lib/viban_web/router.ex

scope "/api", VibanWeb do
  pipe_through :api

  # PR endpoints
  post "/tasks/:id/pr", TaskController, :create_pr
  post "/tasks/:id/detect-pr", TaskController, :detect_pr
  patch "/tasks/:id/pr-status", TaskController, :refresh_pr_status
end
```

```elixir
# backend/lib/viban_web/controllers/task_controller.ex

defmodule VibanWeb.TaskController do
  use VibanWeb, :controller

  alias Viban.Kanban
  alias Viban.GitHub.Client
  alias Viban.GitHub.PRDetector

  def create_pr(conn, %{"id" => task_id}) do
    task = Kanban.get_task!(task_id)
    repo = get_repo(task)

    case Client.create_pr(
      repo,
      "main",
      task.branch_name,
      task.title,
      build_pr_body(task)
    ) do
      {:ok, pr} ->
        {:ok, updated} = Kanban.link_pr(task, pr.url, pr.number, pr.status)
        json(conn, %{task: task_json(updated)})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: error})
    end
  end

  def detect_pr(conn, %{"id" => task_id}) do
    task = Kanban.get_task!(task_id)

    case PRDetector.detect_and_link_pr(task) do
      {:ok, updated} when is_struct(updated) ->
        json(conn, %{task: task_json(updated), found: true})

      {:ok, :no_pr_found} ->
        json(conn, %{found: false})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: error})
    end
  end

  def refresh_pr_status(conn, %{"id" => task_id}) do
    task = Kanban.get_task!(task_id)
    repo = get_repo(task)

    case Client.get_pr_status(repo, task.pr_number) do
      {:ok, status} ->
        {:ok, updated} = Kanban.update_pr_status(task, status)
        json(conn, %{task: task_json(updated)})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: error})
    end
  end

  defp build_pr_body(task) do
    """
    ## Summary
    #{task.description || task.title}

    ## Task
    Created from Viban task: #{task.id}

    ---
    🤖 Generated with Viban
    """
  end
end
```

### Background PR Detection

Run periodic checks to detect externally created PRs:

```elixir
# backend/lib/viban/github/pr_sync_worker.ex

defmodule Viban.GitHub.PRSyncWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Viban.GitHub.PRDetector
  alias Viban.Kanban

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "detect_new_prs"}}) do
    # Find tasks with branches but no linked PR
    Kanban.list_tasks_with_branches_no_pr()
    |> Enum.each(&PRDetector.detect_and_link_pr/1)

    :ok
  end

  def perform(%Oban.Job{args: %{"type" => "sync_pr_statuses"}}) do
    PRDetector.sync_all_pr_statuses()
    :ok
  end
end

# Schedule in application.ex or config
# Every 5 minutes check for new PRs
# Every 15 minutes sync PR statuses
```

## Implementation Steps

### Phase 1: Data Model
1. Add PR fields to Task resource (pr_url, pr_number, pr_status, branch_name)
2. Create database migration
3. Add actions for linking and updating PR

### Phase 2: GitHub Integration
1. Create GitHub.Client module with gh CLI wrapper
2. Implement create_pr, find_pr_for_branch, get_pr_status
3. Test with actual GitHub repository

### Phase 3: Branch Tracking
1. Update agent output parser to extract branch names
2. Update task when agent creates branch
3. Store branch name on task

### Phase 4: PR Detection
1. Create PRDetector module
2. Implement detect_and_link_pr function
3. Add detection trigger after task execution completes

### Phase 5: API Endpoints
1. Add create_pr endpoint
2. Add detect_pr endpoint
3. Add refresh_pr_status endpoint

### Phase 6: Frontend - PR Button
1. Create PRButton component
2. Create PRStatusBadge component
3. Add create PR API call

### Phase 7: Frontend - Integration
1. Add PR section to CardDetailsSidePanel
2. Add PR indicator to TaskCard
3. Add loading/error states

### Phase 8: Background Sync
1. Set up Oban worker for PR sync
2. Schedule periodic detection job
3. Schedule periodic status sync job

## Success Criteria

- [ ] "Create PR" button visible when task has branch but no PR
- [ ] "View PR" button visible when PR exists
- [ ] PR created via button appears on GitHub
- [ ] PRs created by agent (via gh) are auto-detected
- [ ] PRs created manually are detected on next sync
- [ ] PR status (open/merged/closed/draft) displays correctly
- [ ] PR status updates automatically
- [ ] Branch name shown on task when no PR yet

## Edge Cases

1. **No Branch**: Task without branch shouldn't show PR button
2. **Multiple PRs**: If multiple PRs for same branch, link the most recent open one
3. **PR Closed Then Reopened**: Status should update correctly
4. **Repository Access**: Handle cases where gh CLI doesn't have repo access
5. **Rate Limiting**: GitHub API rate limits - implement backoff

## Future Enhancements

1. **PR Checks Status**: Show CI/CD status on PR badge
2. **PR Reviews**: Show review status (approved, changes requested)
3. **Auto-merge**: Option to auto-merge when checks pass
4. **PR Comments**: Show/add comments from within Viban
5. **Multi-repo PRs**: Support tasks that span multiple repositories
