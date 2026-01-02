# Claude Code Project Guidelines

This document defines the coding standards and practices for this project when working with Claude Code.

## Project Structure

- `frontend/` - SolidJS frontend application
- `backend/` - Elixir/Ash backend application
- `.claude/agents/` - Custom Claude agents for specialized tasks

## Development URLs

- **App URL**: `https://localhost:8000` (Caddy reverse proxy - use this for testing)
- Backend API: `http://localhost:4000` (Phoenix - don't access directly)
- Frontend dev server: `http://localhost:3000` (Vite - don't access directly)

## Comment Policy

Comments are code smell. This project follows a strict no-comment philosophy:

### Forbidden Comments

1. **Comments explaining "what" the code does**
   ```typescript
   // BAD: Get the user name
   const userName = user.name;

   // BAD: Filter active items
   const activeItems = items.filter(item => item.active);
   ```

2. **Comments explaining "how"**
   ```typescript
   // BAD: Loop through each item and check if active
   for (const item of items) { ... }
   ```

3. **Comments that should be variable/function names**
   ```typescript
   // BAD:
   const x = items.filter(i => i.status === 'active'); // active items

   // GOOD:
   const activeItems = items.filter(item => item.status === 'active');
   ```

### Acceptable Comments

1. **Explaining "why" when it cannot be expressed in code**
   ```typescript
   // Safari requires this workaround due to IndexedDB bug in version 15.4
   const db = await openWithRetry();

   // Business rule: Premium users get extended trial per legal agreement
   const trialDays = user.isPremium ? 30 : 7;
   ```

2. **Section dividers for large files**
   ```typescript
   // ============================================================================
   // Private Functions
   // ============================================================================
   ```

   ```elixir
   # ============================================================================
   # Command Queue Processing
   # ============================================================================
   ```

3. **Documentation for public APIs**
   - `@moduledoc` and `@doc` in Elixir
   - JSDoc for exported functions in TypeScript (sparingly)

### The Rule

If code "needs" a comment to be understood, the code should be refactored instead:
- Extract to a well-named function
- Use descriptive variable names
- Break complex logic into smaller, understandable pieces

## Backend/Frontend Communication

All communication between backend and frontend MUST use one of these two methods:

### 1. Electric SQL (for real-time data sync)
- Used for reactive queries that need real-time updates
- Collections defined in `frontend/src/lib/useKanban.ts` (e.g., `boardsCollection`, `tasksCollection`)
- Use `useLiveQuery` from `@tanstack/solid-db` to query collections

### 2. AshTypescript Generated SDK (for RPC actions)
- Generated file: `frontend/src/lib/generated/ash.ts`
- Regenerate with: `mix ash.codegen` (from backend directory)
- Functions like `create_task`, `update_board`, `move_task`, etc.
- Automatically handles error notifications via `rpcHooks.ts`
- **DO NOT** create custom `fetch` calls to `/api/rpc/run` - use the generated SDK

### Adding New RPC Actions
1. Add `rpc_action` in the domain's `typescript_rpc` block (e.g., `lib/viban/kanban.ex`)
2. Run `mix ash.codegen` to regenerate the SDK
3. Import and use the generated function in frontend

## Code Quality Standards

### TypeScript/SolidJS

- No `any` types unless absolutely necessary
- Minimal type casting - restructure code so TypeScript infers correctly
- Use reactive primitives correctly (createSignal, createEffect, createMemo)
- Proper error boundaries and loading states

### Elixir/Ash

- Extract complex actions to separate modules
- Use proper Ash conventions for resources, policies, and relationships
- `@moduledoc` and `@doc` for public APIs
- Clear module organization

## When Working with Claude

1. Always examine existing codebase patterns before implementing
2. Follow established conventions in the project
3. Choose simpler solutions when equivalent options exist
4. Express intent through code structure and naming, not comments
5. Run tests before considering work complete
