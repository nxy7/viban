---
title: Git Integration
description: Learn how Viban uses Git worktrees to provide isolated environments for each task.
---

# Git Integration

Viban uses Git worktrees to provide isolated environments for each task. Learn how this integration works and how to manage your code.

## How Worktrees Work

When you start a task, Viban:

1. Creates a new branch from your base branch
2. Sets up a git worktree for that branch
3. Points the AI agent to the worktree directory
4. AI makes changes in isolation

```
your-repo/
├── .git/                    # Main repository
├── src/                     # Main working directory
└── .worktrees/
    ├── task-abc123/         # Worktree for task abc123
    │   ├── .git             # Worktree git reference
    │   └── src/
    └── task-def456/         # Worktree for task def456
        └── ...
```

## Benefits

### Parallel Development

Multiple tasks can run simultaneously without conflicts:

- Task A modifies `auth.ts`
- Task B modifies `auth.ts`
- No merge conflicts until review

### Clean Rollback

If a task goes wrong:

```bash
# Simply delete the worktree
git worktree remove .worktrees/task-abc123
```

### Easy Review

Each task's changes are isolated:

```bash
# View changes for a specific task
cd .worktrees/task-abc123
git diff main
```

## Workflow

### 1. Task Starts

```bash
# Viban creates branch and worktree
git branch task/abc123-add-auth main
git worktree add .worktrees/task-abc123 task/abc123-add-auth
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
# From main working directory
git merge task/abc123-add-auth
```

Or use the UI merge button.

### 5. Cleanup

After merge, Viban cleans up:

```bash
git worktree remove .worktrees/task-abc123
git branch -d task/abc123-add-auth
```

## Branch Naming

Default branch pattern: `task/{task-id}-{slug}`

Configure in settings:

```elixir
config :viban, :git,
  branch_pattern: "viban/{task_id}"
```

## GitHub Integration

### Connecting Repositories

1. Go to Project Settings
2. Click "Connect Repository"
3. Authenticate with GitHub
4. Select your repository

### Pull Requests

Viban can automatically create PRs:

```yaml
# .viban/config.yaml
github:
  auto_pr: true
  pr_template: |
    ## Changes
    $TASK_DESCRIPTION

    ## Testing
    - [ ] Tests pass
    - [ ] Code reviewed
```

### PR on Complete

When a task completes with `auto_pr: true`:

1. Pushes branch to origin
2. Creates PR with task description
3. Links PR in task details

## Troubleshooting

### Worktree Creation Fails

```
fatal: 'path' is already checked out
```

**Solution**: Another worktree exists for this branch.

```bash
git worktree list
git worktree remove <path>
```

### Branch Conflicts

If the base branch moved significantly:

1. Cancel the task
2. Delete the worktree
3. Recreate the task

### Large Repositories

For large repos, clone with `--single-branch`:

```bash
git clone --single-branch --branch main <repo>
```

Or configure shallow worktrees:

```elixir
config :viban, :git,
  shallow_worktrees: true,
  depth: 1
```
