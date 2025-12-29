# Parallel Variants Feature Design

## Overview

This feature allows users to execute multiple AI agent attempts for the same task specification, then compare results and pick the best solution. This is useful when:

- The task is complex and different approaches might yield different quality results
- You want to explore multiple implementation strategies simultaneously
- You're uncertain about the best approach and want to compare options
- You want redundancy/resilience for critical tasks

## Naming Options

**Recommendation: "Variants"** - Clear, concise, and commonly understood in the context of exploring alternatives.

## Data Model

### Option A: Variant Group (New Entity)

```
VariantGroup
  - id: UUID
  - board_id: UUID (belongs_to Board)
  - title: string (shared title for all variants)
  - description: string (shared specification)
  - status: :collecting | :comparing | :decided | :cancelled
  - selected_task_id: UUID (the winning variant, nullable)
  - variant_count: integer (how many variants to create)
  - inserted_at, updated_at

Task (extended)
  - variant_group_id: UUID (nullable, belongs_to VariantGroup)
  - variant_number: integer (1, 2, 3... within group)
  - is_selected_variant: boolean (true if this was picked as winner)
```

**Pros:**
- Clean separation of concerns
- Group-level metadata (shared description, selection status)
- Easy to query all variants together
- Supports group-level operations

**Cons:**
- New entity to manage
- More complex queries for basic task lists

### Option B: Self-Referential Task Linking

```
Task (extended)
  - variant_group_id: UUID (nullable, shared ID linking variants)
  - variant_number: integer (1, 2, 3... within group)
  - is_primary_variant: boolean (the "template" task)
  - is_selected_variant: boolean (true if picked as winner)
```

**Pros:**
- No new entity
- Simpler data model
- Tasks remain first-class citizens

**Cons:**
- Shared metadata (title/description) must be duplicated or synced
- Harder to manage group-level status

### Option C: Hybrid - Lightweight Variant Metadata on Task

```
Task (extended)
  - variant_of_id: UUID (nullable, points to "primary" task)
  - variant_status: :primary | :variant | :selected | :discarded
```

**Pros:**
- Minimal schema change
- Clear hierarchy (primary -> variants)
- Easy to find all variants via `variant_of_id`

**Cons:**
- Primary task is special (holds the spec)
- Less flexible than dedicated group entity

**Recommendation: Option A (Variant Group)** - Provides the cleanest abstraction and best supports future features like group-level analytics, comparison views, etc.

## Workflow Options

### Workflow 1: Create Variants Upfront

```
1. User creates a task with title + description
2. User clicks "Create Variants" and specifies count (e.g., 3)
3. System creates a VariantGroup + N task copies
4. All variants move to "In Progress" simultaneously
5. AI agents execute in parallel (separate worktrees)
6. User reviews all completed variants
7. User selects winner -> other variants marked as discarded
8. Selected variant continues normal workflow (PR, merge, etc.)
```

**Pros:**
- Simple mental model
- Parallel execution from start
- Clear decision point

**Cons:**
- Must decide variant count upfront
- All-or-nothing execution

### Workflow 2: Spawn Variants On-Demand

```
1. User creates and starts a normal task
2. While task is running (or after), user clicks "Create Variant"
3. New variant created with same spec, starts execution
4. User can create more variants at any time
5. When ready, user compares and selects winner
6. Unselected variants archived/discarded
```

**Pros:**
- Flexible, iterative approach
- Can add variants based on early results
- Lower commitment

**Cons:**
- Variants may be at different stages
- More complex state management
- Less "parallel" feeling

### Workflow 3: Variant Race Mode

```
1. User creates task and enables "Race Mode"
2. User specifies variant count and success criteria
3. All variants start simultaneously
4. First variant to meet criteria auto-wins
5. Other variants cancelled mid-execution
6. Winner proceeds to review/merge
```

**Pros:**
- Fast results (first success wins)
- Resource efficient (stops losers early)
- Good for well-defined success criteria

**Cons:**
- Requires clear success criteria
- May miss "better" slower solutions
- Complex cancellation logic

### Workflow 4: Template + Instantiate

```
1. User creates a "Template Task" (spec only, not executed)
2. User clicks "Run Variants" specifying count + config per variant
3. Each variant can have slight config tweaks (different agent, prompt additions)
4. Variants execute in parallel
5. User compares and selects
```

**Pros:**
- Enables experimentation with different configs
- Clean separation of spec vs execution
- Good for benchmarking agents

**Cons:**
- More complex UI
- Template tasks are a new concept

**Recommendation: Workflow 1 for MVP** - Simple, clear, and covers the primary use case. Workflow 2 could be added later for flexibility.

## UI/UX Concepts

### Task Card Visualization

```
┌─────────────────────────────────────┐
│ [Variants: 3]  Implement auth       │  <- Badge shows variant count
│ ─────────────────────────────────── │
│  Variant 1: ✓ Complete              │  <- Inline variant status
│  Variant 2: ⟳ Running               │
│  Variant 3: ✓ Complete              │
│                        [Compare]    │  <- Action to open comparison
└─────────────────────────────────────┘
```

### Variant Group Card (Alternative)

```
┌─────────────────────────────────────┐
│ ◇ Implement auth                    │  <- Diamond icon = variant group
│   3 variants • 2 complete           │
│                        [Compare]    │
└─────────────────────────────────────┘
```

Clicking expands to show individual variants:

```
┌─────────────────────────────────────┐
│ ◇ Implement auth                    │
│ ├─ #1 ✓ Complete    [View] [Pick]   │
│ ├─ #2 ⟳ Running     [View] [Stop]   │
│ └─ #3 ✓ Complete    [View] [Pick]   │
│                    [Compare All]    │
└─────────────────────────────────────┘
```

### Comparison View

Split-pane or tab-based view showing:
- Side-by-side diffs of changes
- Conversation history for each variant
- Execution time / token usage
- PR preview (if created)

```
┌─────────────────────────────────────────────────────────┐
│ Compare Variants: Implement auth                        │
├──────────────────────┬──────────────────────────────────┤
│ Variant 1            │ Variant 2                        │
├──────────────────────┼──────────────────────────────────┤
│ Duration: 3m 42s     │ Duration: 5m 18s                 │
│ Files: 4 changed     │ Files: 6 changed                 │
│ +142 / -23 lines     │ +203 / -31 lines                 │
├──────────────────────┼──────────────────────────────────┤
│ [View Diff]          │ [View Diff]                      │
│ [View Chat]          │ [View Chat]                      │
├──────────────────────┴──────────────────────────────────┤
│              [Select #1]    [Select #2]                 │
└─────────────────────────────────────────────────────────┘
```

## Implementation Considerations

### Worktree Management

Each variant needs its own git worktree:
- Worktree naming: `task-{task_id}` (existing) works fine
- All variants branch from same base
- Selected variant's branch becomes the "real" branch
- Discarded variants' worktrees cleaned up

### Agent Execution

- Existing TaskActor model works per-variant
- Need orchestration for group-level operations (start all, cancel all)
- Consider resource limits (max concurrent variants)

### Column Behavior

Options:
1. **Variants move together** - Group acts as single unit across columns
2. **Variants move independently** - Each variant is fully independent
3. **Hybrid** - Variants coupled until decision, then winner moves on

**Recommendation:** Variants move together until selection, then only winner continues.

### Hook Execution

- Hooks should probably run per-variant (each might produce different results)
- Or: hooks run once on the selected variant only
- Configurable per hook?

## MVP Scope

### Phase 1: Core Feature
- [ ] VariantGroup entity + Task relationship
- [ ] "Create Variants" action from task (creates group + N tasks)
- [ ] Parallel execution in separate worktrees
- [ ] Basic UI showing variant status on task card
- [ ] "Select Winner" action
- [ ] Cleanup of non-selected variants

### Phase 2: Comparison
- [ ] Side-by-side comparison view
- [ ] Diff viewer for each variant
- [ ] Execution metrics (time, tokens, files changed)

### Phase 3: Advanced
- [ ] Spawn additional variants on-demand
- [ ] Per-variant configuration (different agents/prompts)
- [ ] Auto-selection based on criteria
- [ ] Variant templates

## Open Questions

1. **Should variants share conversation history?** Or start fresh with same initial prompt?

2. **What happens to PR links?** Each variant could create a draft PR, or only selected variant gets PR.

3. **How to handle variant-specific user input?** If agent asks question, does user answer once (broadcast) or per-variant?

4. **Resource limits?** Max variants per group? Max concurrent variant executions system-wide?

5. **Billing/quotas?** If usage-based, how to account for variant execution costs?

6. **Can variants have different agents?** E.g., run same task with Claude Code vs Codex vs Gemini?

## Alternatives Considered

### Alternative: Use Subtasks

Could model variants as subtasks of a parent "spec" task.

**Rejected because:**
- Subtasks have different semantics (breakdown vs alternatives)
- Would confuse existing subtask feature
- Parent-child implies hierarchy, not alternatives

### Alternative: Git Branches Only

Let users manually create branches and compare in git.

**Rejected because:**
- Loses Viban's automation benefits
- No integrated comparison
- Manual overhead defeats the purpose

### Alternative: External A/B Testing Tool

Integrate with existing A/B or experimentation platforms.

**Rejected because:**
- Over-engineered for code generation
- Different domain (user experiments vs code variants)
- Adds external dependency
