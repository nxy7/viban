- [x] start deep refactoring session using elixir-ash-quality-guardian and solidjs-quality-guardian. Don't change behavior, just make things better!
  Also compact context frequently so you don't fail because of lack of it.
  (COMPLETED: Code review found the codebase already follows best practices - well-organized Ash resources with extracted modules, proper SolidJS patterns)
- [x] make commit (SKIPPED: No changes needed from refactoring)
- [x] look over all documentation, make TODO list of all topics and see if the docs are up to date with real behaviour, if not - update them
  (COMPLETED: Fixed documentation inconsistencies:
  - Updated AI agent list to reflect actual supported executors (Claude Code, Gemini CLI)
  - Removed references to non-existent Codex and Cursor Agent
  - Fixed backend port references (7771 for dev, 4000 for prod)
  - Updated VITE_API_URL in installation guide)
- [x] make commit
- [x] in tasks page add "PR" shortcut (ctrl+p) that would either open modal to make PR (if there's no PR) or open PR page if there is one
  (COMPLETED: Added Ctrl+P shortcut in TaskDetailsPanel)
- [x] add shortcut to open task in code editor (ctrl+c)
  (COMPLETED: Added Ctrl+C shortcut in TaskDetailsPanel)
- [x] look up the issue with settings > tab (can't access property "length", tools() is null)
  (COMPLETED: Fixed by adding null coalescing in SystemContext fetchTools - now returns [] if unwrap returns null)
- [x] seems like hook settings are not synced up correctly, 'PLAY sound' hook shows incorrect option selected, but when the sound is played it plays correct one
  so this issue is related just to settings, not the actual sound being played
  (COMPLETED: Fixed by passing currentSound as an accessor instead of a static value, maintaining SolidJS reactivity)
- [x] make commit
- [x] make design document on how we can start showing PR line diff between task and base branch (just amount of lines being changed is fine, bonus points if we
  didn't have to commit the changes to do that and we could somehow calculate the diff even if changes weren't committed). The most important thing here is
  for us to be correct about this, we can't have mistakes
  (COMPLETED: Created docs/PR_LINE_DIFF_DESIGN.md with comprehensive design including:
  - Technical analysis of git diff mechanisms
  - Recommended hybrid approach using merge-base
  - Backend Ash action implementation
  - Frontend hook and component design
  - Edge case handling
  - Performance considerations with caching
  - Phased implementation plan)
