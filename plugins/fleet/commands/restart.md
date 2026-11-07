---
description: Restart Claude Fleet sessions (resumes their conversations)
argument-hint: <name...>
allowed-tools: Bash(fleet restart:*), Bash(fleet ls:*)
---
Restart Claude Fleet sessions (named, always-on Claude Code background sessions in sessions.toml).

Session names: `$ARGUMENTS`

If no names were given, run `fleet ls` and ask me which to restart. Never run `fleet restart`
without names: that restarts every session. Otherwise run exactly `fleet restart -- <names>`.

`fleet` refuses to restart the session you are running in; if it does, tell me to run the command
from another session or a terminal. Tell me the result in one or two lines.
