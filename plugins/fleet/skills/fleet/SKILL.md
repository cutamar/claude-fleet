---
name: fleet
description: Manage Claude Fleet sessions - the user's named, always-on Claude Code background sessions listed in sessions.toml. Use when the user asks which sessions are running, or to add, remove, start, stop, restart or respawn a session by name (e.g. "stop lodestar", "add ~/code/api as api", "is general running?").
allowed-tools: Bash(fleet ls:*), Bash(fleet up:*), Bash(fleet add:*)
user-invocable: false
---
# Claude Fleet

The `fleet` command manages the user's Claude Fleet sessions. Each session has a name and a folder
and runs as a Claude Code background session; stopped sessions resume their last conversation when
started again. Put session names after `--`.

| User wants | Run |
|---|---|
| see sessions / what's running | `fleet ls` (`fleet ls --json` for details) |
| add a session | `fleet add [--model m] [--effort e] [--no-autostart] [--start] -- <name> <folder>` |
| remove a session | `fleet rm [--stop] -- <name>` (conversations are kept) |
| start | `fleet up -- <names>` (no names: every autostart session) |
| stop | `fleet down -- <names>` |
| restart | `fleet restart -- <names>` |
| move onto a new Claude Code version | `fleet respawn -- <names>` |

Rules:

- If it isn't clear which session the user means, run `fleet ls` and ask. Never run `fleet down`,
  `fleet restart` or `fleet respawn` without names: that affects every session.
- `$CLAUDE_CODE_SESSION_ID` starts with the id of the session you are in (the id `fleet ls`
  shows). Stopping that session ends this conversation, so say so before doing it. `fleet restart`
  refuses to restart it; the user has to do that from another session or a terminal.
- A new folder must be trusted once: if `fleet` says it isn't, tell the user to run `claude` there
  and accept the prompt. You can't do it for them.
- The user can also use the quick commands `/fleet:status`, `/fleet:add`, `/fleet:remove`,
  `/fleet:start`, `/fleet:stop` and `/fleet:restart`.
