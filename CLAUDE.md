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

### Hologram (Frontend - Migration Target)

This project is migrating from Phoenix LiveView to Hologram. See `TODO.md` for the migration plan.

**What is Hologram:**
- Full-stack isomorphic Elixir web framework running on top of Phoenix
- Write frontend code in Elixir - it transpiles to JavaScript automatically
- Client-side state management (state lives in browser, not server)
- Uses HTTP/2 for client-server communication (WebSocket-like speed)

**Key Hologram Concepts:**

1. **Pages** - Entry points with routes, always stateful
   ```elixir
   defmodule MyApp.HomePage do
     use Hologram.Page
     route "/"
     layout MyApp.MainLayout

     def init(params, component, server) do
       put_state(component, :count, 0)
     end
   end
   ```

2. **Components** - Reusable UI pieces (stateless or stateful)
   ```elixir
   defmodule MyApp.Counter do
     use Hologram.Component
     prop :initial, :integer, default: 0

     def template do
       ~HOLO"""
       <div>Count: {@count}</div>
       """
     end
   end
   ```

3. **Actions** - Client-side state updates (run in browser)
   ```elixir
   def action(:increment, _params, component) do
     put_state(component, :count, component.state.count + 1)
   end
   ```

4. **Commands** - Server-side operations (database, APIs)
   ```elixir
   # IMPORTANT: Commands take (name, params, server) - no component parameter!
   def command(:save_task, params, server) do
     case Task.create(params) do
       {:ok, task} -> put_action(server, :task_saved, %{task: task})
       {:error, _} -> put_action(server, :save_failed, %{})
     end
   end
   ```

**Template Syntax (`~HOLO` sigil):**
```elixir
~HOLO"""
<div class={@active && "active"}>
  <p>Hello, {@name}!</p>

  {%for item <- @items}
    <li>{item.name}</li>
  {/for}

  {%if @show_details}
    <Details data={@data} />
  {/if}

  <button $click="increment">+1</button>
  <button $click={:save, id: @id}>Save</button>
  <button $click={command: :delete, params: %{id: @id}}>Delete</button>
</div>
"""
```

**Event Types:**
- `$click`, `$blur`, `$focus`, `$change`, `$submit`, `$select`
- `$pointer_down`, `$pointer_up`, `$pointer_move`
- `$transition_start`, `$transition_end`

**State Management:**
```elixir
put_state(component, :key, value)
put_state(component, key1: val1, key2: val2)
put_state(component, [:nested, :path], value)
```

**Navigation:**
```elixir
put_page(component, TargetPage, param: value)
# Or in templates:
<Link to={TargetPage, id: 123}>Go</Link>
```

**Context (shared state across components):**
```elixir
# Emit context
put_context(component, :current_user, user)

# Consume context via prop
prop :user, :map, from_context: :current_user
```

**Current Limitations (as of v0.6.6):**
- No PubSub/server-initiated updates yet (in development)
- ~74% Elixir stdlib coverage (some functions unavailable in browser)
- No file upload support yet
- No drag-and-drop primitives (must implement with pointer events)
- **CRITICAL: Logger is not supported in commands/actions** - `Logger.info`, `Logger.debug`, etc. will crash with "Function :logger_config.allow/2 is not yet ported". Remove all Logger calls from component code.

**Hologram + Phoenix Coexistence:**
- Hologram routes via `plug Hologram.Router` (before Phoenix router)
- Phoenix channels/LiveView can coexist for real-time features
- Gradual migration possible - move pages one at a time

**CRITICAL: Component Initialization Patterns**

Hologram components require careful attention to initialization and statefulness:

**1. Server vs Client Initialization**

Use `init/3` for components that are **part of the initial page render** (rendered server-side):
```elixir
# Server-initialized component (always present in initial HTML)
def init(_props, component, server) do
  component
  |> put_state(:data, [])
  {component, server}  # Must return both component and server
end
```

Use `init/2` for components that are **conditionally rendered** (added dynamically to the page):
```elixir
# Client-initialized component (rendered inside {%if})
def init(_props, component) do
  component
  |> put_state(:data, [])
  |> put_command(:load_data, %{})  # Commands work fine!
  # Return only component (no server in init/2)
end
```

**Key Rule:** If a component is wrapped in `{%if}` in the template, it's client-initialized and needs `init/2`. Otherwise, use `init/3`.

**2. Stateful Components REQUIRE `cid`**

Any component that maintains state (uses `put_state` or has `command` functions) **MUST** have a `cid` attribute when rendered:

```elixir
# CORRECT - Stateful component with cid
{%if @show_modal}
  <CreateBoardModal cid="create_board_modal" />
{/if}

# WRONG - Stateful component without cid will cause KeyError
{%if @show_modal}
  <CreateBoardModal />  # Missing cid!
{/if}
```

The `cid` (Component ID) must be unique among siblings and allows Hologram to route actions and commands correctly.

**3. Commands Work in Both init/2 and init/3 Components**

CRITICAL: Command signature is `command(name, params, server)` - no `component` parameter!

```elixir
# Client-initialized component (init/2)
def init(_props, component) do
  component
  |> put_state(:loading, true)
  |> put_action(:load_data_init)  # Trigger action that calls command
end

# Action calls command
def action(:load_data_init, _params, component) do
  put_command(component, :load_data, %{})
end

# Command signature: (name, params, server) - returns server
def command(:load_data, _params, server) do
  case fetch_data(server) do
    {:ok, data} -> put_action(server, :data_loaded, %{data: data})
    {:error, _} -> put_action(server, :load_failed, %{})
  end
end
```

Commands:
- Take `(name, params, server)` - NO component parameter
- Return `server` (NOT `{component, server}`)
- Use `put_action(server, ...)` to trigger actions

**4. Common Mistakes**

❌ **Passing unused props causes mysterious KeyErrors:**
```elixir
# Don't pass props that aren't used
<CreateBoardModal user={@user} />  # user prop never used - causes KeyError!
```

❌ **Missing cid on stateful components:**
```elixir
# Stateful component without cid
<MyModal />  # Will fail if MyModal uses put_state
```

❌ **Using init/3 for conditionally rendered components:**
```elixir
# Component is conditionally rendered
{%if @show_modal}
  <MyModal cid="modal" />  # Needs init/2, not init/3!
{/if}

# In MyModal:
def init(_props, component, server) do  # ERROR - will crash!
  {component, server}
end
```

✅ **Correct patterns:**
```elixir
# Conditionally rendered stateful component
{%if @show_modal}
  <CreateBoardModal cid="board_modal" />
{/if}

# In CreateBoardModal:
def init(_props, component) do  # init/2 for conditionally rendered
  component
  |> put_state(:name, "")
  |> put_state(:error, nil)
  |> put_command(:load_repos, %{})  # Commands work fine!
end

# Command signature: (name, params, server) - returns server
def command(:load_repos, _params, server) do
  user_id = get_cookie(server, "user_id")
  case load_repos(user_id) do
    {:ok, repos} -> put_action(server, :set_repos, %{repos: repos})
    {:error, _} -> put_action(server, :load_failed, %{})
  end
end
```

### Ash Framework (Backend)

- Resources in `lib/viban/kanban/` (SQLite-backed)
- Domain in `lib/viban/kanban.ex`
- Actions define business logic
- Policies define authorization

### Data Layer

- SQLite for persistent storage (via AshSqlite)
- Phoenix Channels for real-time updates (until Hologram PubSub is ready)

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
