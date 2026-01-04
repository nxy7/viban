 - We should be using electric SQL for all realtime communication, not websockets. Make sure we don't have any other things like that in the system. Now we've also added "StateServer" abstraction that
  allows to sync agent state into FE, so if there's need for that we can also use it.
  Definitely we don't want to complicate things right now with 2 schemes - websockets and Electric.
  Go over whole project to make sure we're following this rule. Use @.claude/agents/autonomous-task-executor.md to do that.
- make sure the project works, run tests, test things manually in the browser and make git commit
- start deep refactoring session using elixir-ash-quality-guardian and solidjs-quality-guardian. Don't change behavior, just make things better!
  Also compact context frequently so you don't fail because of lack of it.
