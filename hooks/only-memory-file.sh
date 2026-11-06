#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit) for read-only agents that have memory.
# Usage in agent frontmatter: only-memory-file.sh <agent-name>
# Allows writes only to that agent's own notes file:
#   <project>/.claude/agent-memory-local/<agent-name>/MEMORY.md
# Exit 2 = block (stderr is shown to the agent), exit 0 = allow.

agent="${1:-}"
if ! [[ "$agent" =~ ^[a-z0-9-]+$ ]]; then
  echo "Blocked: memory guard misconfigured (missing agent name)." >&2; exit 2
fi
suffix="/.claude/agent-memory-local/$agent/MEMORY.md"

path="$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"
deny() { echo "Blocked: $agent is read-only except for its notes file .claude/agent-memory-local/$agent/MEMORY.md ($1)." >&2; exit 2; }

[ -z "$path" ] && deny "no file path"
[ -L "$path" ] && deny "target is a symlink"
resolved="$(realpath -m -- "$path" 2>/dev/null)" || deny "unresolvable path"

[[ "$resolved" == "$HOME"/* ]] || deny "outside home"
[[ "$resolved" == *"$suffix" ]] || deny "not its notes file"
# No symlinked directory anywhere on the way to the notes file.
dir="$(dirname -- "$path")"
[ -e "$dir" ] && [ "$(realpath -- "$dir")" != "$(dirname -- "$resolved")" ] && deny "symlinked folder"
exit 0
