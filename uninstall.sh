#!/usr/bin/env bash
# Remove everything install.sh added. Your sessions.toml and agent notes stay.
# Running sessions keep running; stop them first with `fleet down`.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
HYPR="$HOME/.config/hypr/custom"

unlink_if_ours() { if [ -L "$1" ] && [[ "$(readlink "$1")" == "$REPO"* ]]; then rm "$1"; echo "removed: $1"; fi; }

if [ -f "$HOME/.config/systemd/user/claude-fleet.service" ]; then
  systemctl --user disable claude-fleet.service >/dev/null 2>&1 || true
  rm "$HOME/.config/systemd/user/claude-fleet.service"
  systemctl --user daemon-reload
  echo "removed: systemd user service claude-fleet (linger left as is; turn off with: loginctl disable-linger $USER)"
fi
unlink_if_ours "$HOME/.local/bin/fleet"
unlink_if_ours "$HOME/.local/bin/fleet-mcp"
if command -v claude >/dev/null && claude mcp get fleet 2>/dev/null | grep -qF "fleet-mcp"; then
  claude mcp remove --scope user fleet >/dev/null 2>&1 && echo "removed: MCP server 'fleet'"
fi
unlink_if_ours "$HOME/.claude/fleet-hooks"
for f in "$REPO"/agents/*.md; do unlink_if_ours "$HOME/.claude/agents/$(basename "$f")"; done
unlink_if_ours "$HOME/.claude/skills/dev-team"

for file in "$HYPR/execs.lua" "$HYPR/keybinds.lua"; do
  [ -f "$file" ] || continue
  if grep -qF -- "-- >>> claude-fleet >>>" "$file"; then
    sed -i '/^-- >>> claude-fleet >>>$/,/^-- <<< claude-fleet <<<$/d' "$file"
    echo "unhooked: $file"
  fi
done
if [ -f "$HOME/.config/autostart/claude-fleet.desktop" ]; then
  rm "$HOME/.config/autostart/claude-fleet.desktop"; echo "removed: ~/.config/autostart/claude-fleet.desktop"
fi
