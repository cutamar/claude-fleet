# Claude Fleet

**Named, always-on Claude Code sessions you can manage from any chat.**

You probably keep several Claude Code sessions open, one per project. Claude Fleet keeps them running:
they start at login, pick up their last conversation, run in auto mode with Remote Control on
(so you can reach them from your phone), and one hotkey or command lets you switch between them.

Manage them from any session, including from your phone, with `/fleet:status`, `/fleet:stop lodestar` and
friends, or just by asking.

Looking for the dev team of subagents (`/dev-team`) that used to live here? It moved to
[claude-skills](https://github.com/cutamar/claude-skills).

```text
$ fleet ls
NAME       STATE              AUTO  MODEL    FOLDER
my-app     idle (bg 0de7c580) yes   default  ~/code/my-app
website    busy (bg 27f83d63) yes   sonnet   ~/code/website
infra      stopped            no    default  ~/code/infra
```

---

## Quick start

### Option A: let Claude install it (recommended)

Paste this into any Claude Code session:

```text
Install Claude Fleet from https://github.com/cutamar/claude-fleet. Follow its INSTALL.md.
```

Claude checks the requirements, clones the repo, asks which projects you want as sessions, and sets
everything up. It asks you before it changes your desktop's autostart.

### Option B: three commands

```bash
git clone https://github.com/cutamar/claude-fleet ~/claude-fleet
~/claude-fleet/install.sh --systemd     # or without --systemd: start at login instead of boot
fleet add my-app ~/code/my-app && fleet up
```

Then open the switcher with `fleet`, or press **Super+Alt+C** on Hyprland.

**Requirements:** Linux, [Claude Code](https://code.claude.com) 2.1.3xx or newer, Python 3.11+, `git`.
Optional: `fzf` (for `fleet pick`), `kitty` or `alacritty` (for the hotkey window), `notify-send`.

---

## What you get

### 1. Sessions that survive reboots

Sessions are listed in `sessions.toml` (name, folder, options). `fleet up` starts each one as a
Claude Code **background session** in its folder with:

- **its name:** shown in the prompt, the session list and `/resume`
- **its last conversation:** the newest saved conversation with that name in that folder is resumed
- **auto mode:** a safety classifier approves routine actions instead of prompting
- **Remote Control:** reachable from claude.ai/code and the Claude mobile app

Two ways to start them automatically:

| | When | How |
|---|---|---|
| **At boot** (`install.sh --systemd`) | right after the machine starts, **before you log in**. Reach your sessions from your phone while the PC sits at the login screen. | systemd user service `claude-fleet` + `loginctl enable-linger`. Sessions stop cleanly at shutdown. |
| **At login** (`install.sh`) | when you log in to your desktop | Hyprland `exec` or an XDG autostart entry, plus a desktop notification |

Either way, `fleet up --boot` waits for the network and starts the sessions marked `autostart`.
Running `fleet up` again is always safe: sessions that already run are left alone.

### 2. Switching between sessions

`fleet` (or the hotkey) opens Claude Code's **agent view**:

| Key | Does |
|---|---|
| `↑` `↓` | move between sessions |
| `Space` | peek at a session's latest output, and reply from there |
| `Enter` / `→` | open the session |
| `←` (empty prompt) | back to the list; the session keeps running |
| `Ctrl+F` / `Ctrl+R` | find / rename |

In the input box at the bottom of agent view, `Enter` starts a **new** session. To reply to an
existing one, use the peek panel.

### 3. Manage sessions from any chat: `/fleet:*`

The installer adds the `fleet` plugin to Claude Code, so every session (and the Claude app on your
phone) has these commands. Type `/fleet` to see them:

| Command | Does |
|---|---|
| `/fleet:status` | table of your sessions and whether they're running |
| `/fleet:add <name> <folder> [model]` | add a session and start it |
| `/fleet:remove <name>` | stop it if it runs, then remove it (its conversations are kept) |
| `/fleet:start [names...]` | start these (no names: all autostart ones) |
| `/fleet:stop <names...>` | stop these |
| `/fleet:restart <names...>` | restart these, resuming their conversations |

The commands just run `fleet`, pre-approved, so there are no permission prompts. You can also ask in
plain words ("is lodestar running?", "add ~/code/api as api on sonnet"): the plugin's skill teaches
Claude the `fleet` command, and it asks when it isn't sure which session you mean.

Stopping the session you are typing in ends that chat (`fleet` stops it last). `fleet restart`
refuses to restart it, because it would stop before it could start again: do that from another
session or a terminal.

---

## Commands

| Command | Does |
|---|---|
| `fleet` / `fleet ui` | agent view: list, peek, open sessions |
| `fleet pick` | fuzzy picker over your configured sessions; starts a stopped one and opens it |
| `fleet attach <name>` | open one session in this terminal (starts it if needed) |
| `fleet ls [--json]` | your sessions and their state |
| `fleet up [names]` | start autostart sessions (or the named ones), resuming each; `--fresh` starts new conversations |
| `fleet down [names]` | stop sessions (the conversation is kept and resumed next time) |
| `fleet restart [names]` | stop + start |
| `fleet respawn [names]` | move running sessions onto a new Claude Code version after `claude update` |
| `fleet add <name> <dir> [--model m] [--no-autostart] [--start]` | add a session |
| `fleet rm <name> [--stop]` | remove a session from `sessions.toml` (its conversations are kept) |
| `fleet edit` | open `sessions.toml` |
| `fleet logs <name>` | recent output |

## Configuration: `sessions.toml`

```toml
[defaults]
permission_mode = "auto"     # auto | default | acceptEdits | plan
remote_control = true

[[session]]
name = "my-app"
dir = "~/code/my-app"
autostart = true
# model = "sonnet"           # opus | sonnet | haiku | full model id
# effort = "high"            # low | medium | high | xhigh | max
# agent = "planner"          # run the whole session as one agent from ~/.claude/agents
# args = ["--add-dir", "~/shared"]
```

Each folder must be **trusted** once: run `claude` in it and accept the prompt. `fleet ls` marks
untrusted folders.

## Troubleshooting

- **A session doesn't start:** run `fleet up <name>` in a terminal to see why (missing folder,
  untrusted folder). Automatic runs log to `~/.local/state/claude-fleet/fleet.log`; the boot service
  also logs to `journalctl --user -u claude-fleet`.
- **Boot service:** `systemctl --user status claude-fleet`. It needs Claude Code's login stored in
  `~/.claude/.credentials.json` (the Linux default) and a home folder that is available before login
  (not encrypted with systemd-homed or similar). Restarting the service with `systemctl --user restart`
  stops and resumes all sessions. Switch back to login autostart with
  `systemctl --user disable claude-fleet && ./install.sh`.
- **Hotkey on other desktops:** bind any key to `fleet ui` in your desktop's keyboard settings.
- **After `claude update`:** run `fleet respawn` so running sessions use the new version.
- **`/fleet:` commands missing:** plugins load at session start; `fleet respawn` reloads them.
  `claude plugin list` should show `fleet@claude-fleet`.

## Uninstall

```bash
fleet down && ~/claude-fleet/uninstall.sh
```

This removes the link, the `fleet` plugin, the autostart entry or boot service, and the hotkey. Your
`sessions.toml` stays. Linger is left on (other services may use it): `loginctl disable-linger` turns it off.

## Repository layout

```text
bin/fleet                     the session manager (Python, stdlib only)
plugins/fleet/                the fleet plugin: /fleet:* commands and the fleet skill
.claude-plugin/marketplace.json
systemd/claude-fleet.service the boot service (install.sh --systemd)
install.sh / uninstall.sh
INSTALL.md                    step-by-step install instructions for Claude
```

## License

MIT
