# Claude Fleet: notes for Claude working on this repo

- `bin/fleet` must stay stdlib-only Python 3.11+ (it runs at login, outside any venv).
- `plugins/fleet` (the `/fleet:*` commands and `fleet` skill) only runs the `fleet` CLI, names after
  `--`; put behavior in `fleet`, not in the prompts. Run `claude plugin validate plugins/fleet`
  after editing it. `fleet` detects the session it runs in via `$CLAUDE_CODE_SESSION_ID` (`is_self`).
- Running sessions come from `claude agents --json`; sessions are matched by `name`. Never kill
  `claude` processes directly. Use `claude stop/respawn <id>`.
- Resuming an empty session (no user message) silently creates a new id, so `last_session_id`
  only picks transcripts that contain a user message.
- `install.sh` edits Hyprland's `custom/*.lua` only between `claude-fleet` marker lines; keep
  `uninstall.sh` in sync with anything the installer adds.
- The dev team (agents, `/dev-team`, guard hooks, progress panel) lives in
  github.com/cutamar/claude-skills now; `install.sh` removes leftover links from older versions.
- The sessions list lives at `~/.config/claude-fleet/sessions.toml` (`$FLEET_CONFIG` overrides;
  a legacy `<repo>/sessions.toml` is still read until `install.sh` moves it).
  `sessions.example.toml` is the template.
- `systemd/claude-fleet.service` is a oneshot with `RemainAfterExit`; ExecStart/ExecStop are prefixed
  with `-` on purpose (a failed start must not make systemd kill the sessions that did start).
  `fleet up` holds `~/.local/state/claude-fleet/up.lock` so boot and login starts can't overlap.
