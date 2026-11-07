---
description: Stop Claude Fleet sessions (their conversations are kept)
argument-hint: <name...>
allowed-tools: Bash(fleet down:*), Bash(fleet ls:*)
---
Stop Claude Fleet sessions (named, always-on Claude Code background sessions in sessions.toml).

Session names: `$ARGUMENTS`

If no names were given, run `fleet ls` and ask me which to stop. Never run `fleet down` without
names: that stops every session. Otherwise run exactly `fleet down -- <names>`.

If one of them is the session you are running in, this conversation ends when it stops; `fleet`
stops that one last. Tell me the result in one or two lines.
