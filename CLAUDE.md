# Claude Code Project Guidelines

This document defines the coding standards and practices for this project when working with Claude Code.

## Project Structure

- `backend/` - Elixir/Ash backend application with Phoenix LiveView frontend
- `.claude/agents/` - Custom Claude agents for specialized tasks

## Development URLs

- **Dev**: `http://localhost:7777` (Phoenix HTTP)
- **Prod**: `http://localhost:7777` (deploy mode, Phoenix HTTP)

## Starting Development

```bash
# Start all services (database + backend)
just dev

# Or manually:
docker compose up db &
cd backend && mix phx.server
```

## Comment Policy

Comments are code smell. This project follows a strict no-comment philosophy:

### Forbidden Comments

1. **Comments explaining "what" the code does**
   ```elixir
   # BAD: Get the user name
   user_name = user.name
   ```

2. **Comments explaining "how"**
   ```elixir
   # BAD: Loop through each item and check if active
   Enum.filter(items, &(&1.active))
   ```

3. **Comments that should be variable/function names**
   ```elixir
   # BAD:
   x = Enum.filter(items, &(&1.status == :active)) # active items

   # GOOD:
   active_items = Enum.filter(items, &(&1.status == :active))
   ```

### Acceptable Comments

1. **Explaining "why" when it cannot be expressed in code**
   ```elixir
   # Business rule: Premium users get extended trial per legal agreement
   trial_days = if user.premium?, do: 30, else: 7
   ```

2. **Section dividers for large files**
   ```elixir
   # ============================================================================
   # Command Queue Processing
   # ============================================================================
   ```

3. **Documentation for public APIs**
   - `@moduledoc` and `@doc` in Elixir

### The Rule

If code "needs" a comment to be understood, the code should be refactored instead:
- Extract to a well-named function
- Use descriptive variable names
- Break complex logic into smaller, understandable pieces

## Architecture

### Phoenix LiveView (UI)

- All UI is server-rendered with Phoenix LiveView
- LiveView files in `lib/viban_web/live/`
- Components in `lib/viban_web/live/*/components/`
- Real-time updates via PubSub

### Ash Framework (Backend)

- Resources in `lib/viban/kanban_lite/` (SQLite-backed)
- Domain in `lib/viban/kanban_lite.ex`
- Actions define business logic
- Policies define authorization

### Data Layer

- SQLite for persistent storage (via AshSqlite)
- PubSub for real-time updates between LiveView processes

## Code Quality Standards

### Elixir/Ash

- Extract complex actions to separate modules
- Use proper Ash conventions for resources, policies, and relationships
- `@moduledoc` and `@doc` for public APIs
- Clear module organization

### Phoenix LiveView

- Keep assigns minimal
- Use components for reusable UI pieces
- Handle events in the parent LiveView when possible
- Use `push_patch` for URL changes, `push_navigate` for full page changes

## Versioning

This project uses **CalVer** (Calendar Versioning) with the format: `YYYY.MM.PATCH`

- `YYYY` - Full year (e.g., 2026)
- `MM` - Month (01-12)
- `PATCH` - Incremental patch number within the month, starting at 0

Examples: `2026.01.0`, `2026.01.1`, `2026.02.0`

## When Working with Claude

1. Always examine existing codebase patterns before implementing
2. Follow established conventions in the project
3. Choose simpler solutions when equivalent options exist
4. Express intent through code structure and naming, not comments
5. Run tests before considering work complete
