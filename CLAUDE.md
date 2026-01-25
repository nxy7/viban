# Claude Code Project Guidelines

This document defines the coding standards and practices for this project when working with Claude Code.

## Project Structure

- `backend/` - Elixir/Ash backend application with Phoenix LiveView frontend
- `.claude/agents/` - Custom Claude agents for specialized tasks

## Frontend Stack

**Stack:** LiveVue (LiveView + Vue 3)

**Key Architecture:**
- LiveView handles server state and Ash action calls
- Vue components handle UI rendering and interactions
- Phoenix PubSub for real-time updates (via LiveView)
- No Node.js at runtime (SSR disabled)

## Development URLs

- **Dev**: `http://localhost:7777` (Phoenix HTTP)
- **Prod**: `http://localhost:7777` (deploy mode, Phoenix HTTP)

## Starting Development

```bash
# Start backend in development mode (SQLite, no external dependencies)
just dev

# Or manually:
cd backend && mix deps.get && mix ash.setup && mix phx.server
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

### Server-Centric Design Philosophy

**This application is fundamentally server-centric.** The frontend is a view into server state, not an independent state machine.

**Core Principles:**

1. **Server is the Source of Truth**
   - All business logic lives on the server
   - All state changes are initiated and validated by the server
   - Database is the single source of truth

2. **Frontend is a Reactive View**
   - Frontend displays what the server tells it to display
   - No optimistic updates
   - No client-side state that doesn't mirror server state
   - UI updates happen in response to server broadcasts

3. **Communication Pattern**
   - Client sends commands/intents (e.g., "move this task")
   - Server processes, validates, executes business logic
   - Server broadcasts state changes to ALL connected clients
   - Clients update UI based on broadcasts

4. **Hook System**
   - Hooks execute entirely on the server
   - Hook results broadcast as events to clients
   - Clients react to hook events (e.g., play sound, show notification)
   - Never execute hook logic in the browser

**Example Flow:**
```
User drags task → Client sends command → Server validates & executes
                                      ↓
                            Server updates database
                                      ↓
                    Server executes hooks (play sound, move task, etc)
                                      ↓
                Server broadcasts events via Phoenix Channel
                                      ↓
              ALL clients update UI based on broadcasts
```

**Anti-Patterns to Avoid:**
- Client updating its own state before server confirmation
- Client making decisions about what should happen
- Client executing business logic
- Client-side validation that doesn't match server validation

**Hook Execution (Server-Centric Pattern):**

Hooks execute entirely on the server and broadcast their effects via structured events:

```elixir
# Hook executes on server
def execute(_task, _column, opts) do
  board_id = Keyword.get(opts, :board_id)
  execution = Keyword.get(opts, :execution)

  # Broadcast via HookNotifier
  HookNotifier.broadcast_hook_executed(
    board_id,
    execution,
    effects: %{play_sound: %{sound: "ding"}}
  )
end
```

Broadcasts use `hook_executed` events with full metadata:

```json
{
  "hook_id": "system:play-sound",
  "hook_name": "Play Sound",
  "task_id": "uuid",
  "triggering_column_id": "uuid",
  "result": "ok",
  "effects": {
    "play_sound": {"sound": "ding"}
  }
}
```

The frontend interprets hook events and takes appropriate actions:

```javascript
// Frontend receives hook_executed event
function handleHookExecuted(payload) {
  // React to hook effects
  if (payload.effects.play_sound) {
    playSound(payload.effects.play_sound.sound);
  }
}
```

This ensures:
- Server controls when and how hooks execute
- Clients receive structured, semantic events
- Hook metadata is always available (which column triggered it, which task, etc.)
- Easy to add new hook types without changing client code structure

### Ash Framework (Backend)

- Resources in `lib/viban/kanban/` (SQLite-backed)
- Domain in `lib/viban/kanban.ex`
- Actions define business logic
- Policies define authorization

### Data Layer

- SQLite for persistent storage (via AshSqlite)
- Phoenix PubSub for real-time updates (via LiveView)

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
