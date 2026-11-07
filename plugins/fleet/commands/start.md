---
description: Start Claude Fleet sessions (no names = all autostart ones)
argument-hint: [name...]
allowed-tools: Bash(fleet up:*)
---
Start Claude Fleet sessions (named, always-on Claude Code background sessions in sessions.toml).
Each one resumes its last conversation; sessions that already run are left alone.

Session names: `$ARGUMENTS`

Run exactly one command: `fleet up -- <names>` with the names above, or plain `fleet up` if none
were given. Tell me the result in one or two lines.
