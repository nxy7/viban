---
title: Task Refinement
description: Learn how to use AI-powered task refinement to transform simple descriptions into actionable prompts.
---

# Task Refinement

Learn how to use AI-powered task refinement to transform simple descriptions into high-quality, actionable prompts.

## What is Task Refinement?

Task refinement uses AI to enhance your task descriptions. A simple idea like "add user authentication" becomes a detailed specification with:

- Clear objectives
- Acceptance criteria
- Scope boundaries
- Implementation guidance

## Using the Refine Button

1. Create or open a task
2. Click the **Refine** button
3. Wait for AI processing (usually 5-10 seconds)
4. Review the enhanced description
5. Edit if needed, then save

## Before and After

### Before Refinement

```
Add dark mode to the app
```

### After Refinement

```markdown
## Objective
Implement a dark mode theme toggle that allows users to switch between light and dark color schemes.

## Requirements
- Add a theme toggle button in the header/navigation
- Implement dark color palette using CSS custom properties
- Persist user preference in localStorage
- Respect system preference (prefers-color-scheme) by default
- Ensure smooth transition between themes

## Acceptance Criteria
- [ ] Toggle button switches between light/dark modes
- [ ] Theme preference persists across sessions
- [ ] All components render correctly in both themes
- [ ] Transitions are smooth (no flash of wrong theme)
- [ ] System preference is respected on first visit

## Out of Scope
- Multiple theme options (only light/dark)
- Per-page theme settings
- Theme scheduling
```

## How It Works

The refinement process:

1. **Analyzes your input**: Understands intent and context
2. **Adds structure**: Organizes into sections
3. **Expands details**: Adds missing requirements
4. **Defines boundaries**: Sets clear scope
5. **Creates checklist**: Measurable acceptance criteria

## Best Practices

### Provide Context

More context leads to better refinement:

```
# Less context (okay)
Add search

# More context (better)
Add search to find products by name and description
```

### Review and Edit

Always review refined descriptions:
- Remove irrelevant suggestions
- Add project-specific requirements
- Adjust scope as needed

### Iterative Refinement

You can refine multiple times:
1. Start with a rough idea
2. Refine once for structure
3. Add your own details
4. Refine again for polish

## How It's Implemented

Task refinement uses Claude Code CLI with the Haiku model for fast, cost-effective processing:

- **Model**: Haiku (optimized for speed)
- **Timeout**: 60 seconds
- **Output format**: Markdown with structured sections

The refinement prompt instructs the AI to:
- Output only the refined task (no conversational text)
- Add clear title and objective
- Include acceptance criteria
- Define appropriate scope

## Troubleshooting

### Refinement Takes Too Long

- Check AI agent availability
- Try refreshing and retrying
- Check network connectivity

### Output Quality Issues

- Provide more input context
- Try refining again
- Manually edit the output
