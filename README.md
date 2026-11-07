# Claude Fleet

**Named, always-on Claude Code sessions plus a ready-made dev team of subagents.**

You probably keep several Claude Code sessions open, one per project. Claude Fleet keeps them running:
they start at login, pick up their last conversation, run in auto mode with Remote Control on
(so you can reach them from your phone), and one hotkey or command lets you switch between them.

It also installs a **dev team**: an Opus planner, cheaper Sonnet/Haiku workers, read-only reviewers
with real guardrails, and per-agent memory. Plus a live **progress panel** that shows what the team is doing.

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

Optional: the live `/dev-team` progress panel. Run this inside Claude Code:

```text
/plugin install dev-team-view --marketplace cutamar/claude-fleet
```

**Requirements:** Linux, [Claude Code](https://code.claude.com) 2.1.3xx or newer, Python 3.11+, `git`, `jq`.
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

### 3. A dev team: `/dev-team <task>`

| Agent | Model | Memory | Role |
|---|---|---|---|
| `planner` | Opus | ✓ | read-only architect: tasks, parallel waves, risk, model per task |
| `implementer` | Sonnet | ✓ | one task per run, self-review, status report |
| `test-engineer` | Sonnet | ✓ | tests (test-first when asked) |
| `debugger` | Sonnet | ✓ | root cause + minimal verified fix |
| `reviewer` | Sonnet | ✓ | read-only gate: spec compliance + code quality |
| `security-reviewer` | Opus | ✓ | read-only, for security-sensitive changes |
| `scout` | Haiku | – | fast lookups (a cheap replacement for general-purpose agents) |
| `docs-writer` | Haiku | – | docs |

How a `/dev-team` run goes:

1. The planner writes a plan of small tasks grouped into **waves**.
2. You approve it.
3. Each wave runs **in parallel**, each task in its own git worktree, then the worktrees are merged.
4. Every task is reviewed before the next wave starts. Failed fixes escalate to a stronger model.
5. The whole branch gets a final review, then docs are updated.

Progress is kept in `.claude/plans/<slug>.progress.md`, so long runs survive context compaction.
You can also call one agent directly: *"use the planner to…"*, *"@scout where is…"*.

Built on conventions from [obra/superpowers](https://github.com/obra/superpowers),
[everything-claude-code](https://github.com/affaan-m/everything-claude-code),
[wshobson/agents](https://github.com/wshobson/agents) and the
[official subagent docs](https://code.claude.com/docs/en/sub-agents).

### 4. Guardrails and memory

- **Read-only agents really are read-only.** `hooks/readonly-bash.sh` blocks shell commands that write
  files, change git state or install packages.
- **Memory without losing that.** Agents that run repeatedly keep dated notes in
  `<project>/.claude/agent-memory-local/<agent>/MEMORY.md`, loaded automatically at start.
  Memory normally gives an agent Write/Edit, so `hooks/only-memory-file.sh` limits each read-only agent
  to **its own notes file and nothing else**.
- At the end of a `/dev-team` run, stable rules from the notes are proposed for `CLAUDE.md`
  (applied only with your OK).
- Workers can't spawn their own subagents, every agent has a turn cap, and every subagent call names
  its model, so nothing silently runs on Opus.

### 5. Manage sessions from any chat (MCP server)

The installer registers a `fleet` MCP server (user scope), so you can manage the fleet by just asking
Claude, in any session or from your phone: *"add a session for ~/code/api on sonnet and start it"*,
*"stop website"*, *"which sessions are running?"*.

| Tool | Does |
|---|---|
| `list_sessions` | configured sessions with folder, options and live state |
| `add_session` | add one (name, folder, model, effort, autostart), optionally start it |
| `remove_session` | remove one from `sessions.toml`; `stop: true` stops it first. Conversations are kept |
| `start_sessions` / `stop_sessions` / `restart_sessions` | same as `fleet up` / `down` / `restart` |

For exact control, use the slash commands instead (type `/mcp__fleet` and pick one). Each tells
Claude exactly which tool to call, so "session" can't be misread:

| Command | Does |
|---|---|
| `/mcp__fleet__status` | table of sessions and their state |
| `/mcp__fleet__add <name> <dir> [model]` | add a session and start it |
| `/mcp__fleet__remove <name>` | stop it if running, then remove it |
| `/mcp__fleet__start [names...]` | start these (default: all autostart ones) |
| `/mcp__fleet__stop <names...>` | stop these |
| `/mcp__fleet__restart <names...>` | restart these |

The server (`bin/fleet-mcp`, stdlib Python) just runs the `fleet` command, so the CLI and the tools
always agree. Skip it with `install.sh --no-mcp`, or register it by hand:
`claude mcp add --scope user fleet -- ~/.local/bin/fleet-mcp`. Stopping the session you are chatting
from ends that chat.

### 6. Live progress panel (optional mod)

The `dev-team-view` mod adds a panel beside the chat that follows the current run, plus a one-line
summary above the prompt:

```text
Add --version flag
running · wave 2/3 · base 8d59750

Wave 1
T1   DONE       ✅   implementer/haiku · flag added
Wave 2
T2   running    -    test-engineer/sonnet
T3   DONE_WITH_CONCERNS ❌ r1 implementer/sonnet · README row

Rulings: 1 · last: print bare version — user asked — low
```

```text
dev-team: Add --version flag · wave 2/3 · 1 running · 1 need fixes · 1/3 done   [Open] [Hide]
```

It opens by itself when a run starts. Open it any time with `/dev-team-view`.

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
| `fleet memory` / `fleet memory sync [repo]` | agent notes sizes / copy notes back from worktree runs |

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
# agent = "planner"          # run the whole session as one agent
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
- **New agents not showing up:** agent definitions load at session start; `fleet respawn` reloads them.
- **Notes growing large:** `fleet memory` warns past 180 lines, because only the first 200 are loaded.

## Uninstall

```bash
fleet down && ~/claude-fleet/uninstall.sh
```

This removes the links, the MCP server, the autostart entry or boot service, and the hotkey. Your `sessions.toml` and
agent notes stay. Linger is left on (other services may use it): `loginctl disable-linger` turns it off.
Remove the panel with `/plugin uninstall dev-team-view`.

## Repository layout

```text
bin/fleet                     the session manager (Python, stdlib only)
bin/fleet-mcp                 MCP server exposing fleet as tools (Python, stdlib only)
agents/                       dev-team subagent definitions
skills/dev-team/SKILL.md      the /dev-team orchestration workflow
hooks/                        read-only and memory-file guards (+ test.sh)
plugins/dev-team-view/        the progress panel mod
.claude-plugin/marketplace.json
systemd/claude-fleet.service the boot service (install.sh --systemd)
install.sh / uninstall.sh
INSTALL.md                    step-by-step install instructions for Claude
```

## License

MIT
