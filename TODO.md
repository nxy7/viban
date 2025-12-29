Tasks to do:
- [x] collapse hooks in "Task Details" tab. If info about 10 hooks is next to each other then we should collapse it into
  one row: '11 hooks (7 successful, 4 pending)' or '5 hooks (1 successful, 1 failed, 3 skipped)'. This text should be
  'clickable' and when we click it we should get details of hook execution (things like error message for failed hooks)
- [x] add tests for stopping task execution. Maybe we can do it by having some script hook like 'sleep 30' that would be executed
  and we would stop agent execution and see if this script was stopped somehow?
  (Tests already exist in hook_system_comprehensive_test.exs - see "Task Movement During Hook Execution" tests)
- [x] see if our info about hooks in docs is up to date. I think that at the very least we should describe how 'transparent' hooks
  are supposed to be working
  (Added "Transparent Hooks" section to HOOKS_SYSTEM.md with table comparing transparent vs normal hooks)
- [x] add 'hook defaults' where we're adding new hooks. Then when hook is added to column it should use default 'transparency' and
  'execute once' settings.
  (Added default_execute_once and default_transparent fields to Hook resource, and frontend now applies defaults when hook is selected)
- [x] add 'non removable' hooks. I want "Execute AI" to be non removable hook on "In Progress" column, so it's visible in hooks list
  but user can't remove it. This will allow user to put something before or after "Execute AI" but we can guarantee AI behavior
  in specific column
  (Added removable flag to ColumnHook, "Execute AI" is now auto-added to "In Progress" with removable=false, UI shows "Required" instead of remove button)
- [x] writing message should not execute AI by default, instead it should just put the task in "In Progress" column.
  AI Execution would just be hook in our model.
  (Modified handleStartExecutor to: 1) append user prompt to task description, 2) move task to "In Progress" to trigger hooks.
   When task is already in "In Progress", it still directly starts executor since hooks only run on column entry.)
- [x] seems like moving tasks is still not working correctly, it's visible f.e. when you try to move task to the top of the list. Even
  if 'task shadow' is moved to the top of the list, the purple line is not on the top and the task is then moved to the position of
  purple line
  (Fixed in KanbanBoard.tsx onDragOver - changed position calculation to use midpoint of target element instead of center.y)
- [x] in board settings show repository name. Right now I'm seeing empty space and link actually points to 'undefined' so something
  is wrong here.
  (Fixed Repository resource and frontend: added 'local' provider type, made provider-specific fields optional, updated useRepositories
   query to select all fields including full_name, updated RepositoryConfig to use local_path instead of path, and improved
   RepositoryDisplay to handle local repos without external links)
