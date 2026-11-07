---
description: Add a Claude Fleet session and start it
argument-hint: <name> <folder> [model]
allowed-tools: Bash(fleet add:*)
---
Add a Claude Fleet session (a named, always-on Claude Code background session in sessions.toml).

Arguments: `$ARGUMENTS`, meaning `<name> <folder> [model]`. The model is optional (opus, sonnet,
haiku or a full model id). If the name or folder is missing, ask me for it instead of guessing.

Run exactly one command:

```
fleet add --start [--model <model>] -- <name> <folder>
```

Then tell me the result in one or two lines. If it says the folder isn't trusted, tell me to run
`claude` in that folder once and accept the prompt, then `/fleet:start <name>`.
