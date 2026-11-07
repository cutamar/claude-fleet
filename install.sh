#!/usr/bin/env bash
# Install Claude Fleet. Safe to re-run; undo with ./uninstall.sh
#   - links the `fleet` command into ~/.local/bin
#   - installs the `fleet` plugin (/fleet:status, /fleet:stop, ...) from this repo's marketplace
#   - creates ~/.config/claude-fleet/sessions.toml from sessions.example.toml if you don't have one yet
#   - autostart at login: Hyprland (plus Super+Alt+C hotkey) if found, otherwise an XDG autostart entry
# Options:
#   --systemd        start sessions at boot, before you log in (systemd user service + linger);
#                    replaces the login autostart (the Hyprland hotkey stays)
#   --no-autostart   skip all autostart / hotkey setup
#   --no-plugin      don't install the `fleet` plugin
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
AUTOSTART=1
SYSTEMD=0
PLUGIN=1
for arg in "$@"; do
  case "$arg" in
    --no-autostart) AUTOSTART=0 ;;
    --systemd) SYSTEMD=1 ;;
    --no-plugin) PLUGIN=0 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1 ($2)" >&2; exit 1; }; }
need claude "install Claude Code first: https://code.claude.com"
need python3 "Python 3.11 or newer"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' \
  || { echo "Python 3.11 or newer is required (found $(python3 -V))" >&2; exit 1; }

link() {  # link SRC DEST, refusing to overwrite a real file
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "skip: $dest exists and is not a link (move it away to install)"; return
  fi
  ln -sfn "$src" "$dest"; echo "link: $dest"
}

mkdir -p "$HOME/.local/bin"
chmod +x "$REPO/bin/fleet"
link "$REPO/bin/fleet" "$HOME/.local/bin/fleet"

# Older versions also shipped the dev team (now github.com/cutamar/claude-skills) and an MCP
# server: remove their leftover links that point into this repo.
for l in "$HOME/.local/bin/fleet-mcp" "$HOME/.claude/fleet-hooks" "$HOME/.claude/skills/dev-team" \
         "$HOME"/.claude/agents/*.md; do
  if [ -L "$l" ] && [[ "$(readlink "$l")" == "$REPO"/* ]]; then rm "$l"; echo "gone: $l (old version)"; fi
done
if claude mcp get fleet 2>/dev/null | grep -qF "fleet-mcp"; then
  claude mcp remove --scope user fleet >/dev/null 2>&1 && echo "gone: MCP server 'fleet' (replaced by the fleet plugin)"
fi
claude plugin uninstall dev-team-view@claude-fleet >/dev/null 2>&1 \
  && echo "gone: dev-team-view@claude-fleet (now in claude-skills)" || true

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-fleet"
mkdir -p "$CONF_DIR"
if [ ! -f "$CONF_DIR/sessions.toml" ] && [ -f "$REPO/sessions.toml" ]; then
  mv "$REPO/sessions.toml" "$CONF_DIR/sessions.toml"   # older versions kept it in the repo
  echo "moved: sessions.toml -> $CONF_DIR/sessions.toml"
elif [ ! -f "$CONF_DIR/sessions.toml" ]; then
  cp "$REPO/sessions.example.toml" "$CONF_DIR/sessions.toml"
  echo "new:  $CONF_DIR/sessions.toml (edit it with: fleet edit, or use: fleet add <name> <folder>)"
elif [ -f "$REPO/sessions.toml" ]; then
  echo "note: $REPO/sessions.toml is no longer used ($CONF_DIR/sessions.toml is); delete it when you're sure"
fi

if [ "$AUTOSTART" = 1 ] && [ "$SYSTEMD" = 1 ]; then
  command -v systemctl >/dev/null || { echo "systemd not found; drop --systemd" >&2; exit 1; }
  UNIT_DIR="$HOME/.config/systemd/user"
  mkdir -p "$UNIT_DIR"
  cp "$REPO/systemd/claude-fleet.service" "$UNIT_DIR/claude-fleet.service"
  systemctl --user daemon-reload
  systemctl --user enable claude-fleet.service >/dev/null 2>&1 && echo "on:   systemd user service claude-fleet (starts at boot)"
  if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != "yes" ]; then
    if loginctl enable-linger "$USER" 2>/dev/null; then
      echo "on:   linger for $USER (your user services start at boot, before login)"
    else
      echo "todo: run 'sudo loginctl enable-linger $USER' so the service starts before login"
    fi
  fi
  # The service replaces the login autostart; keep only the hotkey.
  HYPR_EXECS="$HOME/.config/hypr/custom/execs.lua"
  if [ -f "$HYPR_EXECS" ] && grep -qF -- "-- >>> claude-fleet >>>" "$HYPR_EXECS"; then
    sed -i '/^-- >>> claude-fleet >>>$/,/^-- <<< claude-fleet <<<$/d' "$HYPR_EXECS"
    echo "off:  Hyprland login autostart (the service does it now)"
  fi
  rm -f "$HOME/.config/autostart/claude-fleet.desktop"
  HYPR_KEYS="$HOME/.config/hypr/custom/keybinds.lua"
  if [ -f "$HYPR_KEYS" ] && ! grep -qF -- "-- >>> claude-fleet >>>" "$HYPR_KEYS"; then
    printf '\n%s\n%s\n%s\n' "-- >>> claude-fleet >>>" 'hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd("$HOME/.local/bin/fleet ui"), { description = "Claude Fleet: switch sessions" })' "-- <<< claude-fleet <<<" >> "$HYPR_KEYS"
    echo "hook: $HYPR_KEYS"
  fi
elif [ "$AUTOSTART" = 1 ]; then
  HYPR="$HOME/.config/hypr/custom"
  MARK_BEGIN="-- >>> claude-fleet >>>"
  MARK_END="-- <<< claude-fleet <<<"
  add_block() {  # add_block FILE CONTENT
    local file="$1" content="$2"
    if grep -qF -- "$MARK_BEGIN" "$file"; then echo "ok:   $file already hooked"; return; fi
    printf '\n%s\n%s\n%s\n' "$MARK_BEGIN" "$content" "$MARK_END" >> "$file"
    echo "hook: $file"
  }
  if [ -f "$HYPR/execs.lua" ] && [ -f "$HYPR/keybinds.lua" ]; then
    add_block "$HYPR/execs.lua" 'hl.on("hyprland.start", function ()
    hl.exec_cmd("$HOME/.local/bin/fleet up --boot")
end)'
    add_block "$HYPR/keybinds.lua" 'hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd("$HOME/.local/bin/fleet ui"), { description = "Claude Fleet: switch sessions" })'
  else
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/claude-fleet.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Claude Fleet
Comment=Start your Claude Code sessions
Exec=$HOME/.local/bin/fleet up --boot
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
    echo "new:  ~/.config/autostart/claude-fleet.desktop (starts sessions at login)"
    echo "tip:  bind a key to 'fleet ui' in your desktop's keyboard settings to open the switcher"
  fi
fi

if [ "$PLUGIN" = 1 ]; then
  claude plugin marketplace list 2>/dev/null | grep -qF "$REPO" \
    || claude plugin marketplace add "$REPO" >/dev/null 2>&1 || true
  if claude plugin install fleet@claude-fleet >/dev/null 2>&1; then
    echo "on:   fleet plugin: /fleet:status, /fleet:add, /fleet:stop, ... in every Claude session"
  else
    echo "todo: claude plugin marketplace add $REPO && claude plugin install fleet@claude-fleet"
  fi
fi

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "note: add ~/.local/bin to your PATH" ;; esac
echo
echo "Done. Next: fleet ls   (then fleet up to start your sessions)"
echo "Running sessions see the /fleet: commands after: fleet respawn"
