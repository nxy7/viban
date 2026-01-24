# Hologram Framework Learnings

This document captures key findings and patterns discovered while working with Hologram v0.6.6.

## Event Handling & Parameters

### ✅ Working Patterns

#### 1. Page-Level Actions with Parameters
Use the full `action:`, `params:`, `target:` syntax to pass parameters to page-level actions:

```elixir
<button $click={action: :my_action, params: %{id: @item.id, name: @item.name}, target: "page"}>
  Click Me
</button>
```

Page handler:
```elixir
def action(:my_action, %{id: id, name: name}, component) do
  # Use id and name
  put_state(component, :selected_id, id)
end
```

#### 2. Component Actions WITHOUT Parameters
Simple actions without parameters work fine:

```elixir
<button $click="toggle_something">Toggle</button>
```

```elixir
def action(:toggle_something, _params, component) do
  put_state(component, :is_open, !component.state.is_open)
end
```

#### 3. Modal Closing Pattern
For closing modals from components, target the page action directly:

```elixir
<!-- In component template -->
<button $click={action: :hide_modal, target: "page"}>Close</button>
```

#### 3. Component Actions WITH Parameters
Component actions CAN receive parameters using keyword list syntax:

```elixir
{%for {item, index} <- Enum.with_index(@items)}
  <button $click={:select_item, index: index}>
    {item.name}
  </button>
{/for}
```

Handler receives the parameters:
```elixir
def action(:select_item, %{index: index}, component) do
  item = Enum.at(component.state.items, index)
  put_state(component, :selected_item, item)
end
```

### ❌ Non-Working Patterns

#### Using $click:param Syntax
**DOES NOT WORK** in Hologram v0.6.6:

```elixir
<!-- This syntax does NOT pass parameters -->
<button $click="select_item" $click:id={item.id}>Bad</button>
```

This results in the action receiving only `%{event: %{client_x: ..., client_y: ...}}` without custom parameters.

## Template Syntax

### Iteration with Index
```elixir
{%for {item, index} <- Enum.with_index(@items)}
  <div>Item {index}: {item.name}</div>
{/for}
```

### Conditional Classes
```elixir
<div class={if @active, do: "bg-blue-500", else: "bg-gray-500"}>
  Content
</div>
```

### String Interpolation in Classes
```elixir
<div class={"base-class #{if @selected, do: "selected-class", else: ""}"}></div>
```

## State Management

### Component Initialization
```elixir
def init(_props, component) do
  component
  |> put_state(:counter, 0)
  |> put_state(:items, [])
  |> put_action(:load_initial_data)  # Trigger initial data load
end
```

### Updating State
```elixir
# Single value
put_state(component, :key, value)

# Multiple values
component
|> put_state(:key1, value1)
|> put_state(:key2, value2)

# Or use keyword list
put_state(component, key1: value1, key2: value2)
```

## Server Commands

Commands execute on the server and can access session data:

```elixir
def command(:load_data, _params, server) do
  user_id = server.session[:user_id] || get_cookie(server, "my_cookie")

  case MyModule.fetch_data(user_id) do
    {:ok, data} ->
      put_action(server, :data_loaded, %{data: data})

    {:error, reason} ->
      put_action(server, :load_failed, %{error: reason})
  end
end
```

## GitHub API Integration Notes

- GitHub API returns **atom keys**, not string keys
- Access fields like `repo.full_name`, not `repo["full_name"]`
- Always provide default values for optional fields: `repo.default_branch || "main"`

## Elixir Standard Library Limitations

Hologram transpiles Elixir to JavaScript, but only ~74% of Elixir's stdlib is currently ported. Some functions are not yet available:

### Not Available (as of v0.6.6)

- `:binary.split/3` - Used internally by `String.split/2` with binary patterns
- May affect other string manipulation functions

### Workarounds

When you encounter "Function X is not yet ported" errors:

1. **Use simpler alternatives**: Replace complex string operations with basic ones
2. **Use existing data**: If GitHub API provides `repo.name`, use it instead of extracting from `full_name`
3. **Server-side processing**: Move complex operations to `command/3` functions that run on the server

Example:
```elixir
# Instead of this (uses String.split internally):
[_owner, repo_name] = String.split(full_name, "/")

# Do this (use data that's already available):
repo_name = repo.name
```

## Data Serialization

Hologram transpiles Elixir to JavaScript, which means all data passed to the client must be serializable to JavaScript. Certain Elixir types cause errors:

### Types That Cannot Be Serialized

1. **DateTime structs** - `%DateTime{}` and `%NaiveDateTime{}` cause "can't access property 'type', e is null"
2. **nil values** - JavaScript's `null` doesn't map cleanly to Hologram's type system
3. **UUID structs** - Elixir UUIDs are structs and must be converted to strings

### Solution: Serialize All Data

Always serialize data before passing to client state:

```elixir
# BAD - Will cause "can't access property 'type', e is null"
%{
  id: user.id,                    # UUID struct
  name: user.name,                # might be nil
  inserted_at: user.inserted_at   # DateTime struct
}

# GOOD - All types safe for JavaScript
%{
  id: to_string(user.id),         # String
  name: user.name || "",          # String (never nil)
  # Don't include DateTime fields at all
}
```

### Serialization Checklist

When preparing data for Hologram client state:
- [ ] Convert UUIDs to strings with `to_string/1`
- [ ] Replace nil values with defaults (`nil || ""`, `nil || 0`, etc.)
- [ ] Remove DateTime fields entirely (or convert to Unix timestamps if needed)
- [ ] Ensure all nested data is also serialized
- [ ] Use atoms carefully (they work, but keep them simple)

## Common Gotchas

1. **Logger is not supported** - Causes crashes with `:logger_config.allow/2` errors
2. **Elixir stdlib coverage** - ~74% ported, some functions like `:binary.split/3` unavailable
3. **Backdrop clicks** - Use `$click="stop_propagation"` on inner elements to prevent closing on content click
4. **Case sensitivity** - Action names and state keys are atoms, be consistent
5. **Data serialization** - Always serialize data before passing to client (see Data Serialization section)

## Best Practices

1. **Always read existing code** before implementing patterns
2. **Use page-level actions** when you need to pass parameters
3. **Keep component state minimal** - only what the component needs
4. **Handle errors gracefully** - always pattern match on `{:ok, _}` and `{:error, _}`
5. **Provide user feedback** - loading states, error messages, success confirmations

## Testing Checklist for Modals

- [ ] Modal opens correctly
- [ ] Modal closes via X button
- [ ] Modal closes via Cancel button
- [ ] Modal closes via backdrop click (if intended)
- [ ] Content click doesn't close modal
- [ ] Form validation works
- [ ] Submit button enables/disables correctly
- [ ] Loading states display correctly
- [ ] Error messages display correctly
- [ ] Success flow works end-to-end
