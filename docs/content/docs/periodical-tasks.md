---
title: Periodical Tasks
description: Automate recurring work with scheduled task execution.
---

# Periodical Tasks

::callout{type="warning"}
This feature is currently under development and will be available in an upcoming release.
::

Periodical tasks allow you to schedule recurring work that runs automatically at specified intervals. This is useful for maintenance tasks, regular updates, dependency checks, and other routine operations.

## Overview

Periodical tasks extend the standard Kanban workflow by adding time-based automation. Instead of manually creating and running tasks, you define a schedule and Viban handles the rest.

## Creating a Periodical Task

1. Navigate to your board settings
2. Select the "Periodical Tasks" tab
3. Click "Create Periodical Task"
4. Configure the task:
   - **Name**: A descriptive name for the task
   - **Description**: The task prompt that will be sent to the AI agent
   - **Schedule**: When and how often the task should run
   - **Executor**: Which AI agent should handle the task

## Schedule Options

Periodical tasks support flexible scheduling:

| Schedule Type | Example | Description |
|--------------|---------|-------------|
| Hourly | Every 2 hours | Run at fixed hour intervals |
| Daily | Every day at 9:00 AM | Run once per day at a specific time |
| Weekly | Every Monday at 10:00 AM | Run on specific days of the week |
| Custom Cron | `0 */4 * * *` | Full cron expression for advanced scheduling |

## Use Cases

### Dependency Updates

Schedule a weekly task to check for and update dependencies:

```
Review all dependencies in package.json and mix.exs.
Update any packages with security patches.
Run tests to verify compatibility.
```

### Code Quality Checks

Run daily linting and code quality analysis:

```
Run the full test suite and linter.
Fix any auto-fixable issues.
Report any manual fixes needed in a summary.
```

### Documentation Sync

Keep documentation up to date with weekly reviews:

```
Review recent code changes and update documentation
to reflect any API changes or new features.
```

### Database Maintenance

Schedule regular database optimization:

```
Analyze slow queries from the past week.
Suggest index optimizations.
Clean up any orphaned records.
```

## Execution Behavior

When a periodical task runs:

1. A new task is automatically created in the "Todo" column
2. The task is immediately moved to "In Progress"
3. The configured AI agent executes the task
4. Results appear in the task's activity log
5. On completion, the task moves to "In Review" or "Done" based on outcome

## Managing Periodical Tasks

### Pausing and Resuming

You can pause any periodical task without deleting it. Paused tasks retain their configuration and execution history but won't create new runs until resumed.

### Execution History

Each periodical task maintains a history of past executions, including:
- Start and end times
- Success or failure status
- Links to the generated task instances
- Output summaries

### Notifications

Configure notifications for periodical task events:
- Task started
- Task completed successfully
- Task failed or needs attention

## Best Practices

1. **Start with longer intervals** - Begin with weekly schedules and adjust based on actual needs
2. **Be specific in prompts** - Periodical tasks work best with clear, focused objectives
3. **Review regularly** - Check execution history to ensure tasks are providing value
4. **Use appropriate executors** - Match the task complexity to the right AI agent
