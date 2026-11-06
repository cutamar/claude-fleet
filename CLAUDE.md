# Claude Fleet: notes for Claude working on this repo

- `bin/fleet` must stay stdlib-only Python 3.11+ (it runs at login, outside any venv).
- Running sessions come from `claude agents --json`; sessions are matched by `name`. Never kill
  `claude` processes directly. Use `claude stop/respawn <id>`.
- Resuming an empty session (no user message) silently creates a new id, so `last_session_id`
  only picks transcripts that contain a user message.
- Agent hook paths point to `$HOME/.claude/fleet-hooks/`, a link `install.sh` makes to `hooks/`,
  so agents work wherever the repo is cloned. Run `hooks/test.sh` after editing anything in `hooks/`.
- Read-only agents with `memory: local` need BOTH hooks (readonly-bash + `only-memory-file.sh <name>`):
  memory silently re-grants Write/Edit otherwise. Plugin-packaged agents ignore `hooks`, which is why
  the agents are linked into `~/.claude/agents` instead of shipped as a plugin.
- Worktree subagents write memory inside the worktree; `fleet memory sync` copies it back.
- The `.progress.md` ledger format in `skills/dev-team/SKILL.md` is parsed by
  `plugins/dev-team-view/hooks/register.tsx` (`parseLedger`). Change both together and run
  `claude plugin test plugins/dev-team-view`.
- `install.sh` edits Hyprland's `custom/*.lua` only between `claude-fleet` marker lines; keep
  `uninstall.sh` in sync with anything the installer adds.
- `sessions.toml` is personal and gitignored; `sessions.example.toml` is the template.
