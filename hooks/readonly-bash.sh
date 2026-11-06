#!/usr/bin/env bash
# PreToolUse hook for read-only agents (planner, reviewer, scout, security-reviewer).
# Blocks shell commands that change files, git state or installed packages.
# A backstop, not a sandbox: the agent prompts also say read-only.
# Exit 2 = block (stderr is shown to the agent), exit 0 = allow.

cmd="$(jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

# Ignore quoted text (grep patterns, commit-message lookups) and harmless redirects.
scan="$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" \
        | sed -E 's#[0-9]*>>? */dev/null##g; s#[0-9]*>&[0-9]##g; s#&>/dev/null##g')"

# Start of a command: line start, after ; & | ( ` or after xargs/sudo/env/exec.
at='(^|[;&|(`]|\bxargs|\bsudo|\benv|\bexec)[[:space:]]*'

block() { echo "Blocked: this agent is read-only ($1). Report the change you'd make instead of running it." >&2; exit 2; }

printf '%s' "$scan" | grep -qE '>' && block "output redirection"
printf '%s' "$scan" | grep -qE "${at}(rm|rmdir|mv|cp|ln|tee|touch|mkdir|chmod|chown|truncate|shred|dd|install|patch)\b" && block "file-changing command"
printf '%s' "$scan" | grep -qE "${at}(sed|perl)\b[^;&|]*[[:space:]]-[a-zA-Z]*i" && block "in-place edit"
gitopts='([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[a-zA-Z-]+(=[^[:space:]]*)?)*'
printf '%s' "$scan" | grep -qE "${at}git${gitopts}[[:space:]]+(commit|push|pull|fetch|checkout|switch|reset|rebase|merge|cherry-pick|revert|stash|clean|restore|add|rm|mv|tag|am|apply|init|clone|worktree|gc|prune|config)\b" && block "git write"
printf '%s' "$scan" | grep -qE "${at}git[[:space:]]+([^;&|]*[[:space:]])?(-c[[:space:]]|--exec-path|--upload-pack|--output)" && block "git option that can run or write"
printf '%s' "$scan" | grep -qE "${at}git[[:space:]]+branch[[:space:]]+(-[dDmMcC]|[^-])" && block "git branch change"
printf '%s' "$scan" | grep -qE "${at}(npm|pnpm|yarn|bun|pip|pip3|uv|poetry|cargo|go|gem|composer|pacman|paru|yay|apt|brew)[[:space:]]+(install|i|add|remove|rm|uninstall|update|upgrade|publish|-S|-R)\b" && block "package change"
printf '%s' "$scan" | grep -qE "${at}(curl|wget)\b[^;&|]*[[:space:]](-o|-O|--output|-X[[:space:]]*(POST|PUT|PATCH|DELETE)|-d|--data)" && block "network write"
exit 0
