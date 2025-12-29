# Task execution model

If there are multiple hooks in the same phase they're executed in the order they're defined
If hook was marked with 'single execution' and it has ran at least once in the past it should be skipped

Hooks are executed sequentially allowing user to create 'scenarios' like 2 hooks, one for formatting another one for testing running one after the other.

---

# Expected Behavior (Edge Cases)

## Hook Execution Feedback

| Scenario                    | Expected Behavior                                                   |
| --------------------------- | ------------------------------------------------------------------- |
| Hook starts executing       | Task shows "Executing {HOOK_NAME}" in status badge with purple glow |
| Hook completes successfully | Status clears, task returns to idle state                           |
| Hook fails (non-zero exit)  | Task shows error state with error message, moved to "To Review"     |

## Hook Failure Scenarios

| Scenario                                               | Expected Behavior                                                                                   |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| Hook A fails, Hook B is pending                        | Task is moved to "To Review" and Hook B is cancelled. Task is in error state (shows error message). |
| Hook fails, task has entry hooks on "To Review" column | "To Review" hooks are skipped, task is in error state and error message is shown                    |
| Hook times out                                         | Hook behaves as if it would have just failed                                                        |
| Hook script not found / permission denied              | Treat as error and follow other cases, but display custom message                                   |

## Task Movement During Hook Execution

| Scenario                                                | Expected Behavior                                                                                                                     |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| User manually drags task while hook is running          | Whichever hook was being executed it's stopped immediately (if it was running AI agent we should not leave AI agent process dangling) |
| Hook moves task programmatically (e.g., to "To Review") | Same behaviour as manual drag                                                                                                         |
| Task is deleted while hook is running                   | Hook is stopped same as in other scenarios, then task is deleted                                                                      |

## Multiple Hooks

| Scenario                                           | Expected Behavior                                                                                                                |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Column has 3 hooks: A, B, C - all succeed          | Nothing happens, card id displayed without any effect. All hook executions are displayed in Task Details with green success sign |
| Column has 3 hooks: A succeeds, B fails, C pending | Hook C becomes skipped, Task is moved to "To Review" in Error state                                                              |
| Same hook configured on multiple columns           | Hook is executed each time task enters the column                                                                                |

## "Execute Once" Flag

| Scenario                                               | Expected Behavior                                             |
| ------------------------------------------------------ | ------------------------------------------------------------- |
| Task enters column first time with "execute once" hook | Hook is executed                                              |
| Task re-enters same column (already executed hook)     | Hook is skipped (it should leave a trace in "Details" though) |
| Task re-enters after error cleared                     | Hook is still skipped                                         |

## Agent Hooks (AI-powered)

| Scenario                          | Expected Behavior                                                                       |
| --------------------------------- | --------------------------------------------------------------------------------------- |
| Agent hook starts                 | Card is in working state and shows message of what's going on like "Running Execute AI" |
| Agent hook waiting for user input | Task is moved to "To Review" column without any visual effect                           |
| Agent hook completes task         | Task is moved to "To Review" column without any visual effect                           |
| Agent hook encounters error       | Task is moved to "To Review" column with error effect and appropriate error message     |

## Transparent Hooks

Transparent hooks are designed for background operations that shouldn't affect the main workflow (notifications, logging, analytics, etc).

| Property                    | Transparent Hook                                       | Normal Hook                                            |
| --------------------------- | ------------------------------------------------------ | ------------------------------------------------------ |
| Status display              | Task status NOT changed while running                  | Task shows "Executing {HOOK_NAME}" status              |
| On failure                  | Other hooks continue, task NOT moved to "To Review"    | Remaining hooks cancelled, task moved to "To Review"   |
| Error state preservation    | Preserves existing error state on task                 | May override error state                               |
| Execute when task in error  | YES - transparent hooks still run on tasks with errors | NO - normal hooks are skipped when task is in error    |

### Use Cases

- **Notifications**: Slack/Discord notifications that shouldn't block the workflow
- **Logging/Analytics**: Track hook executions without affecting task state
- **Cleanup tasks**: Run cleanup scripts even if previous hooks failed

### Example

A "Play Sound" hook marked as transparent will play a notification sound but:
- Won't show "Executing Play Sound" status on the task
- Won't stop other hooks if the sound fails to play
- Will still run even if the task is in error state (useful for error notification sounds)

## System Hooks

They're just normal hooks

## Concurrent/Race Conditions

| Scenario                                | Expected Behavior                                                                                                                                                          |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Two users move same task simultaneously | If they move the card into the same column, then second 'move' action would do nothing, if they move them into different columns it's the same as changing columns quickly |
| Task moved rapidly between columns      | Running hooks are cancelled on each move, the rest are skipped and hooks from new column are queued                                                                        |
| Server restart while hook is running    | Ideally we should be able to handle it and maybe pick off from the place where hook ended or 'reapply' it                                                                  |
