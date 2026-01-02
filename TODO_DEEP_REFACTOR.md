# Deep Refactoring Session

## Status: Mostly Complete

## Goals
1. Simplify code and remove unnecessary complexity
2. Remove useless comments (keep only "why" comments per CLAUDE.md)
3. Move free-floating modules to Ash actions where appropriate
4. Reduce duplication in frontend code
5. Improve code organization and maintainability

---

## Completed Work

### Backend

1. ✅ **Removed duplicated `extract_pr_number` function**
   - Kept in `PRDetector` (public)
   - `Client.ex` now calls `PRDetector.extract_pr_number/1`

2. ✅ **Extracted PTY command building to shared utility**
   - Created `ClaudeCode.wrap_with_pty/2` public function
   - `ClaudeRunner` now uses the shared utility

3. ✅ **Removed dead code in `refine_prompt_hook.ex`**
   - Removed commented-out Oban worker code

4. ✅ **Cleaned forbidden comments**
   - `pr_detector.ex` - removed "what" comments
   - Note: `ansi_cleaner.ex` comments kept (explain regex patterns)

### Frontend

1. ✅ **DELETED: TaskChat.tsx (405 lines of dead code)**
   - Removed deprecated, non-functional component

2. ✅ **Extracted duplicated hook reordering logic**
   - Created `/frontend/src/hooks/useHookReordering.ts`
   - Updated `ColumnHookConfig.tsx` and `ColumnSettingsPopup.tsx`

3. ✅ **Created error handling utility**
   - Created `/frontend/src/lib/errorUtils.ts`
   - Updated 11 files (22 occurrences) to use `getErrorMessage()`

4. ✅ **Removed forbidden comments**
   - Cleaned `ColumnHookConfig.tsx` (removed 10+ comments)
   - Cleaned `KanbanBoard.tsx` (removed 15+ comments)
   - Note: Kept algorithmic comments in collision detection (explain "why")

---

## Remaining Work (Medium Priority)

### Backend

1. **Extract inline changes in Repository resource**
   - Lines 180-198: Anonymous change functions could be named modules

2. **Consider moving PRDetector functions to Ash actions**
   - `detect_and_link_pr` -> `Task.Actions.DetectAndLinkPR`
   - `sync_pr_status` -> `Task.Actions.SyncPRStatus`

### Frontend

1. **Split large ColumnSettingsPopup.tsx (857 lines)**
   - Extract GeneralSettings, HooksSettings, HookSection, etc.

2. **Extract collision detection from KanbanBoard.tsx**
   - `createKanbanCollisionDetector` (177 lines)
   - Move to `/frontend/src/lib/collisionDetection.ts`

3. **Note on SortableHookItem:**
   - The two components (ColumnHookConfig and ColumnSettingsPopup) have
     different implementations with different features (sound settings, icons)
   - Merging them would add complexity rather than reduce it
   - Decision: Keep separate but share the reordering hook

---

## Progress Log

### Session Start
- Created tracking file
- Launched quality guardian agents

### Analysis Complete
- Backend: 15+ issues identified
- Frontend: 20+ issues identified

### Session 1 Completed
- [x] Backend: Removed duplicated code (extract_pr_number, PTY commands)
- [x] Backend: Cleaned comments and dead code
- [x] Frontend: Deleted dead TaskChat.tsx (405 lines)
- [x] Frontend: Created useHookReordering hook
- [x] Frontend: Created errorUtils.ts (updated 22 occurrences in 11 files)
- [x] Frontend: Removed ~25 forbidden comments
- All tests passing (57 backend, frontend builds clean)
