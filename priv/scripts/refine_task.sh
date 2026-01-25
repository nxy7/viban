#!/bin/bash
# Wrapper script for Claude Code CLI refinement
# This ensures proper shell environment

# Source nix profile if available
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Run claude with the prompt
exec claude -p "$1" --output-format text --model haiku --no-session-persistence --dangerously-skip-permissions
