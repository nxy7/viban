---
title: Git Integration
description: Learn how Viban uses Git worktrees to provide isolated environments for each task.
---

# Git Integration

Viban uses Git worktrees to provide isolated environments for each task. Learn how this integration works and how to manage your code.

## How Worktrees Work

When you start a task, Viban:

1. Creates a new branch from your repository's default branch
2. Sets up a git worktree for that branch
3. Points the AI agent to the worktree directory
4. AI makes changes in isolation

## Directory Structure

Worktrees are stored in a central location, organized by board and task:

```
~/.local/share/viban/worktrees/
  <board_id>/
    <task_id>/       # Worktree for task
      .git           # Worktree git reference
      src/
      ...
    <task_id_2>/
      ...
```

This keeps worktrees separate from your main repository.

## Branch Naming

Default branch pattern: `task/<task_id>`

You can also provide a custom branch name when creating a worktree. Branch names are:
- Lowercased
- Sanitized (non-alphanumeric characters replaced with hyphens)
- Limited to 50 characters

## Benefits

### Parallel Development

Multiple tasks can run simultaneously without conflicts:

- Task A modifies `auth.ts`
- Task B modifies `auth.ts`
- No merge conflicts until review

### Clean Rollback

If a task goes wrong, the worktree can simply be deleted:

```bash
# Git removes the worktree cleanly
git worktree remove ~/.local/share/viban/worktrees/<board_id>/<task_id>
```

### Easy Review

Each task's changes are isolated:

```bash
# View changes for a specific task
cd ~/.local/share/viban/worktrees/<board_id>/<task_id>
git diff main
```

## Workflow

### 1. Task Starts

Viban creates a branch and worktree:

```bash
# Creates branch from default branch and worktree in one command
git worktree add -b task/<task_id> <worktree_path> <default_branch>
```

### 2. AI Works

The AI agent operates entirely within the worktree:
- All file edits happen there
- Tests run in that environment
- No impact on main working directory

### 3. Task Completes

Worktree remains for review. You can:
- Review changes in the UI
- Navigate to worktree and inspect
- Run additional tests

### 4. Merge

When ready to merge:

```bash
# From main repository
git merge task/<task_id>
```

Or use the UI merge/PR features.

### 5. Cleanup

Worktrees for completed tasks are automatically cleaned up after a configurable TTL (default: 7 days). Cleanup only happens for tasks in terminal columns (Done or Cancelled).

## Repository Setup

### Connecting a Repository

1. Go to Board Settings
2. Click "Add Repository"
3. Provide the repository URL
4. Viban clones the repository locally

### Repository Status

Repositories have these clone states:
- `pending` - Not yet cloned
- `cloning` - Clone in progress
- `cloned` - Ready to use
- `failed` - Clone failed

Worktrees can only be created for repositories with status `cloned`.

## Configuration

Configure worktree behavior via application environment:

```elixir
config :viban,
  worktree_base_path: "~/.local/share/viban/worktrees",
  worktree_ttl_days: 7
```

## Troubleshooting

### Worktree Creation Fails

**Error**: `fatal: '<branch>' is already checked out`

**Solution**: Another worktree exists for this branch.

```bash
git worktree list
git worktree remove <path>
```

### Repository Not Cloned

Worktrees require a cloned repository. Check:
1. Repository is connected to the board
2. Clone status is `cloned`
3. Local path exists and is valid

### Branch Conflicts

If the base branch moved significantly:
1. The task may need to be rebased
2. Or cancel and recreate the task

### Disk Space

Worktrees consume disk space. The automatic cleanup (after TTL) helps, but for large repositories:
- Consider shorter TTL values
- Manually clean up completed tasks
- Monitor disk usage in `~/.local/share/viban/worktrees/`

## GitHub Integration

### Pull Requests

Viban can create pull requests for completed tasks. When a task completes:

1. Changes are committed in the worktree
2. Branch is pushed to origin
3. PR is created via GitHub API
4. PR link is shown in task details

### PR Detection

Viban monitors for PRs associated with task branches and updates task status accordingly.
