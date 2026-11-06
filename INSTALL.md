# Installing Claude Fleet: instructions for Claude

You are Claude Code, and the user asked you to install Claude Fleet. Follow these steps in order.
Keep the user informed in short messages and ask where a step says so. Never run `sudo`.

## 1. Check the requirements

Run each check, then tell the user in one message what's missing:

- Linux (`uname -s` prints `Linux`). macOS and Windows are not supported: stop and say so.
- `claude --version` works.
- `python3 -c 'import sys; print(sys.version_info >= (3, 11))'` prints `True`.
- `git` and `jq` are installed.
- Optional: `fzf` (for `fleet pick`), `kitty` or `alacritty` (for the hotkey window), `notify-send`.

If a required tool is missing, give the user the install command for their distribution
(e.g. `sudo pacman -S jq`, `sudo apt install jq`) and wait. Don't install system packages yourself.

## 2. Get the code

Default location: `~/claude-fleet`. If the user named another folder, use that.

- Folder doesn't exist: `git clone https://github.com/cutamar/claude-fleet ~/claude-fleet`
- Folder exists and is this repo: `git -C ~/claude-fleet pull --ff-only`
- Folder exists and is something else: ask the user for another location.

## 3. Choose the sessions

Ask the user which project folders should become sessions. To help, offer the folders Claude Code
already trusts (only the paths, nothing else from the file):

```bash
jq -r '.projects | to_entries[] | select(.value.hasTrustDialogAccepted==true) | .key' ~/.claude.json
```

For each chosen folder, settle on a short name (letters, digits, `.`, `_`, `-`). Ask whether it
should start at login (default yes) and whether it needs a specific model (default: none).

## 4. Install

Ask the user one question: **"Start these sessions automatically at login?"**
On Hyprland this also adds the Super+Alt+C hotkey. Elsewhere it adds an XDG autostart entry.

```bash
~/claude-fleet/install.sh                  # yes
~/claude-fleet/install.sh --no-autostart   # no
```

The installer creates `sessions.toml` from the example. Remove the example sessions from it and add
the user's:

```bash
fleet add <name> <folder> [--model sonnet] [--no-autostart]
fleet ls
```

If `fleet` isn't found, `~/.local/bin` isn't on PATH: tell the user to add it, and meanwhile use
`~/.local/bin/fleet`.

## 5. Trust and start

`fleet ls` marks folders as `[untrusted]`. For each one, tell the user to run `claude` once in that
folder and accept the trust prompt. You can't do this for them.

Then start the sessions and show the result:

```bash
fleet up
fleet ls
```

## 6. Optional: the progress panel

Ask whether the user wants the live `/dev-team` progress panel. If yes, either ask them to type this
at the Claude Code prompt:

```text
/plugin install dev-team-view --marketplace cutamar/claude-fleet
```

or run it from the shell yourself:

```bash
claude plugin install dev-team-view --marketplace cutamar/claude-fleet
```

## 7. Finish

Tell the user, briefly:

- `fleet` (or Super+Alt+C on Hyprland) opens the session switcher. `Space` peeks, `Enter` opens,
  `←` goes back.
- `/dev-team <task>` runs the agent team in any session.
- Sessions that were already running need `fleet respawn` (or a restart) to see the new agents.
- `fleet down && ~/claude-fleet/uninstall.sh` removes everything.

## Updating later

```bash
git -C ~/claude-fleet pull --ff-only && ~/claude-fleet/install.sh && fleet respawn
```
