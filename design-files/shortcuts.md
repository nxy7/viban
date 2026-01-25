# Keyboard Shortcuts

Context-aware keyboard shortcuts that adapt based on the current view and focused element.

## Context-Aware System

### How It Works
- Shortcuts are registered per-context (global, board view, task panel, modals)
- Active shortcuts depend on current focus and view state
- Conflicting shortcuts resolved by specificity (more specific context wins)
- Shortcut helper modal shows only relevant shortcuts for current context

### Context Hierarchy
1. **Modal** (highest priority) - When modal is open
2. **Task Panel** - When task details panel is open
3. **Board View** - Main board interface
4. **Global** (lowest priority) - Always available

## Global Shortcuts

| Shortcut | Action |
|----------|--------|
| `?` | Open shortcut helper modal |
| `Escape` | Close current modal/panel |
| `Cmd+K` | Open command palette (future) |

## Board View Shortcuts

| Shortcut | Action |
|----------|--------|
| `N` | Create new task |
| `S` | Open board settings |
| `R` | Refresh board |
| `1-9` | Focus column by position |

## Task Panel Shortcuts

| Shortcut | Action |
|----------|--------|
| `Escape` | Close task panel |
| `E` | Edit task title |
| `D` | Focus description editor |
| `Cmd+Enter` | Send message (when in chat input) |
| `Cmd+S` | Save changes |
| `Tab` | Cycle through tabs (Details, Activity, Settings) |

## Modal Shortcuts

| Shortcut | Action |
|----------|--------|
| `Escape` | Close modal |
| `Cmd+Enter` | Submit/confirm |
| `Tab` | Navigate form fields |

## Shortcut Helper Modal

### Behavior
- Triggered by `?` key from any context
- Displays shortcuts grouped by category
- Only shows shortcuts available in current context
- Indicates which shortcuts are currently active vs inactive
- Search/filter shortcuts (future)

### Display Format
```
┌─────────────────────────────────────┐
│ Keyboard Shortcuts                  │
├─────────────────────────────────────┤
│ Current Context: Task Panel         │
├─────────────────────────────────────┤
│ TASK PANEL                          │
│   E         Edit title              │
│   D         Edit description        │
│   Cmd+Enter Send message            │
│                                     │
│ GLOBAL                              │
│   ?         Show shortcuts          │
│   Escape    Close panel             │
└─────────────────────────────────────┘
```

### Context Indicators
- Active shortcuts shown normally
- Inactive shortcuts (from other contexts) shown dimmed or hidden
- Current context highlighted in header

## Implementation Notes

### Registration
- Each view registers its shortcuts on mount
- Shortcuts unregistered on unmount
- Prevent default browser behavior for registered shortcuts

### Conflict Resolution
- More specific context always wins
- Example: `Escape` in modal closes modal, not task panel behind it

### Text Input Handling
- Most shortcuts disabled when focused on text input
- Exception: `Cmd+Enter` to send, `Escape` to blur
