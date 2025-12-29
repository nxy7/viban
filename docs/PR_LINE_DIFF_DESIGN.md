# PR Line Diff Feature - Design Document

## Overview

This document describes the design for displaying line diff statistics (additions/deletions) for tasks that have git worktrees, showing the difference between the task's current state and the base branch.

## Requirements

1. **Accuracy is critical** - The diff numbers must be correct. Incorrect diff counts undermine trust.
2. **Show additions and deletions** - Display lines added and removed (e.g., "+42 / -15")
3. **Handle uncommitted changes** - Bonus: Calculate diff even for uncommitted changes
4. **Real-time updates** - Diff should update as changes are made

## Technical Analysis

### Git Diff Mechanisms

There are several ways to calculate diffs in Git:

#### Option A: Committed Changes Only (`git diff <base-branch>..<task-branch>`)

```bash
git -C /worktree/path diff --stat <base-branch>..HEAD
# or for just line counts:
git -C /worktree/path diff --shortstat <base-branch>..HEAD
```

**Output example:**
```
15 files changed, 342 insertions(+), 87 deletions(-)
```

**Pros:**
- Simple and well-understood
- Fast execution
- No false positives from temporary files

**Cons:**
- Only shows committed changes
- Misses work-in-progress

#### Option B: Include Uncommitted Changes (`git diff <base-branch>...HEAD` + working tree)

```bash
# Compare base branch to current working tree state (including uncommitted)
git -C /worktree/path diff --shortstat <base-branch>
```

Note: Using just `<base-branch>` (not `<base-branch>..HEAD`) compares the base branch to the current working tree, including uncommitted changes.

**Pros:**
- Shows all changes, including uncommitted
- More accurate representation of current state

**Cons:**
- May include temporary/generated files
- Could show noise from build artifacts

#### Option C: Hybrid Approach (Recommended)

```bash
# Get diff from base branch merge-base to current HEAD (committed)
git -C /worktree/path diff --shortstat $(git merge-base <base-branch> HEAD)

# Get diff from base branch merge-base to working tree (including uncommitted)
git -C /worktree/path diff --shortstat $(git merge-base <base-branch> HEAD) HEAD
```

Using `merge-base` ensures we compare against the correct ancestor, even if the base branch has moved forward since the worktree was created.

## Recommended Implementation

### Backend Changes

#### 1. New Ash Action: `get_task_diff`

Add a new action to the Task resource:

```elixir
defmodule Viban.Kanban.Task.Actions.GetDiff do
  @moduledoc """
  Calculates line diff statistics for a task's worktree compared to base branch.
  """

  use Ash.Resource.ManualRead

  def read(query, _data_layer_query, _opts, _context) do
    task = get_task_from_query(query)

    case calculate_diff(task) do
      {:ok, diff_stats} -> {:ok, [diff_stats]}
      {:error, reason} -> {:error, reason}
    end
  end

  defp calculate_diff(%{worktree_path: nil}), do: {:error, :no_worktree}
  defp calculate_diff(%{worktree_path: path, worktree_branch: branch}) do
    with {:ok, base_branch} <- get_base_branch(path),
         {:ok, committed} <- get_committed_diff(path, base_branch),
         {:ok, uncommitted} <- get_uncommitted_diff(path, base_branch) do
      {:ok, %{
        committed_additions: committed.additions,
        committed_deletions: committed.deletions,
        uncommitted_additions: uncommitted.additions,
        uncommitted_deletions: uncommitted.deletions,
        total_additions: committed.additions + uncommitted.additions,
        total_deletions: committed.deletions + uncommitted.deletions
      }}
    end
  end

  defp get_committed_diff(worktree_path, base_branch) do
    args = [
      "-C", worktree_path,
      "diff", "--shortstat",
      "#{base_branch}..HEAD"
    ]
    parse_git_diff_output(System.cmd("git", args, stderr_to_stdout: true))
  end

  defp get_uncommitted_diff(worktree_path, _base_branch) do
    args = [
      "-C", worktree_path,
      "diff", "--shortstat"  # Working tree vs HEAD
    ]
    parse_git_diff_output(System.cmd("git", args, stderr_to_stdout: true))
  end

  defp parse_git_diff_output({output, 0}) do
    # Parse: "15 files changed, 342 insertions(+), 87 deletions(-)"
    additions = extract_number(output, ~r/(\d+) insertion/)
    deletions = extract_number(output, ~r/(\d+) deletion/)
    {:ok, %{additions: additions, deletions: deletions}}
  end
  defp parse_git_diff_output({output, code}) do
    {:error, {:git_error, code, output}}
  end

  defp extract_number(string, regex) do
    case Regex.run(regex, string) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  defp get_base_branch(worktree_path) do
    # Find the repository and get its default branch
    # This requires looking up the Repository for the task's board
    # ...implementation details...
  end
end
```

#### 2. Add to Task Resource

```elixir
# In task.ex
actions do
  read :get_diff do
    description "Get line diff statistics for task's worktree"
    argument :task_id, :uuid, allow_nil?: false
  end
end
```

### Frontend Changes

#### 1. New Hook: `useTaskDiff`

```typescript
export function useTaskDiff(taskId: () => string | undefined) {
  const [diff, setDiff] = createSignal<DiffStats | null>(null);
  const [isLoading, setIsLoading] = createSignal(false);

  createEffect(() => {
    const id = taskId();
    if (!id) return;

    setIsLoading(true);
    sdk.get_task_diff({ task_id: id })
      .then(result => {
        if (result.success) setDiff(result.data);
      })
      .finally(() => setIsLoading(false));
  });

  return { diff, isLoading };
}
```

#### 2. Display Component

```tsx
function DiffBadge(props: { taskId: string }) {
  const { diff, isLoading } = useTaskDiff(() => props.taskId);

  return (
    <Show when={diff()}>
      {(d) => (
        <div class="flex gap-1 text-xs">
          <span class="text-green-500">+{d().total_additions}</span>
          <span class="text-red-500">-{d().total_deletions}</span>
        </div>
      )}
    </Show>
  );
}
```

## Edge Cases and Error Handling

### 1. No Worktree
- Return `null` for diff stats
- UI shows no diff badge

### 2. Base Branch Deleted/Unavailable
- Fall back to comparing against `HEAD~100` or similar
- Show warning in UI
- Log error for debugging

### 3. Git Command Failures
- Return error status
- UI shows "Unable to calculate diff"
- Don't block other functionality

### 4. Large Diffs
- Set reasonable timeout (5 seconds)
- For very large repos, consider caching
- Show "calculating..." indicator

### 5. Binary Files
- Git's `--shortstat` handles these correctly (shows as "binary file changed")
- Parse output to handle this case

### 6. Worktree Path Missing/Invalid
- Check `File.exists?` before running git commands
- Return appropriate error

## Performance Considerations

### Caching Strategy

1. **Cache on commit** - Recalculate when task's `updated_at` changes
2. **Store in database** - Add `diff_additions` and `diff_deletions` columns to tasks
3. **Background refresh** - Use Oban worker to periodically update diffs
4. **Invalidation** - Clear cache when worktree changes detected

### Real-time Updates

For uncommitted changes, polling is acceptable:
- Poll every 5-10 seconds when task panel is open
- Stop polling when panel closes
- Use WebSocket for more immediate updates (future enhancement)

## Implementation Order

### Phase 1: Basic Committed Diff
1. Add Elixir action to calculate committed diff
2. Add RPC endpoint
3. Add frontend hook and display
4. Test with various scenarios

### Phase 2: Uncommitted Changes (Bonus)
1. Extend action to include uncommitted changes
2. Update frontend to show both
3. Add refresh button
4. Add polling mechanism

### Phase 3: Performance Optimization
1. Add database caching
2. Implement background refresh worker
3. Add Electric SQL sync for cached values

## Testing Strategy

### Unit Tests
- Parse git output correctly
- Handle edge cases (no changes, only additions, only deletions)
- Handle malformed output

### Integration Tests
- Create worktree, make changes, verify diff
- Verify against known git state
- Test with uncommitted changes

### Manual Testing
- Verify numbers match `git diff --stat` output
- Test with various file types
- Test with binary files
- Test with large repos

## Security Considerations

1. **Path traversal** - Validate worktree_path is within expected directory
2. **Command injection** - Use `System.cmd` with array args (not string concatenation)
3. **Timeout** - Set timeout on git commands to prevent DoS

## Conclusion

The recommended approach is to start with **committed diff only** (Option A) for reliability, then extend to include uncommitted changes. Using `git diff --shortstat` provides accurate line counts with minimal parsing complexity.

Key principles:
- **Correctness over features** - Better to show no diff than wrong diff
- **Graceful degradation** - Failures should not break the UI
- **Performance aware** - Cache when possible, poll when necessary
