---
description: Remove a Claude Fleet session (stops it first; its conversations are kept)
argument-hint: <name>
allowed-tools: Bash(fleet rm:*), Bash(fleet ls:*)
---
Remove a Claude Fleet session (a named, always-on Claude Code background session in sessions.toml).

Session name: `$ARGUMENTS`

If no name was given, run `fleet ls` and ask me which one to remove. Otherwise run exactly:

```
fleet rm --stop -- <name>
```

and tell me the result in one line.
