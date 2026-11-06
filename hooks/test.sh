#!/usr/bin/env bash
# Tests for the agent guard hooks. Run after editing anything in hooks/.
cd "$(dirname "$0")" || exit 1
fail=0
check() {  # check EXPECTED_EXIT HOOK_CMD JSON_KEY VALUE
  local want="$1" hook="$2" key="$3" val="$4" got
  printf '{"tool_input":{"%s":%s}}' "$key" "$(jq -Rn --arg v "$val" '$v')" | $hook >/dev/null 2>&1
  got=$?
  if [ "$got" != "$want" ]; then echo "FAIL (want $want, got $got): $hook <- $val"; fail=1; fi
}
bash_ok()    { check 0 ./readonly-bash.sh command "$1"; }
bash_block() { check 2 ./readonly-bash.sh command "$1"; }
mem_ok()     { check 0 "./only-memory-file.sh $1" file_path "$2"; }
mem_block()  { check 2 "./only-memory-file.sh $1" file_path "$2"; }

for c in "git log --oneline -20" "git diff main...HEAD" "grep -rn 'rm -rf' src" "pytest -q 2>/dev/null" \
         "ls -la >&2" "git branch -a" "git branch" "cat a | grep x" 'grep -E "a > b" f' "npm test" \
         "git show HEAD --stat" "git log -- config.py" "git diff --stat -- src/add.py" "git status"; do bash_ok "$c"; done
for c in "rm x" "echo a > f" "cat a >> b" "git commit -m x" "sed -i s/a/b/ f" "ls && touch /tmp/x" "git -C . push" \
         "git --no-pager commit" "git branch new" "npm install left-pad" "find . | xargs rm" "curl -o f http://x" \
         "git -c core.pager=x log" "git log --output=f"; do bash_block "$c"; done

P="$(cd .. && pwd)"; M=".claude/agent-memory-local"
mem_ok planner "$P/$M/planner/MEMORY.md"
mem_ok reviewer "$HOME/some-project/$M/reviewer/MEMORY.md"
mem_block planner "$P/$M/reviewer/MEMORY.md"
mem_block planner "$P/$M/planner/other.md"
mem_block planner "$P/$M/planner/../../../bin/fleet"
mem_block planner "$P/CLAUDE.md"
mem_block planner "/etc/x"
mem_block "" "$P/$M/planner/MEMORY.md"
mem_block "bad;name" "$P/$M/planner/MEMORY.md"
tmp="$(mktemp -d "$HOME/.cache/fleet-hooktest.XXXXXX")"
mkdir -p "$tmp/a/$M/planner" "$tmp/b/$M"
ln -s "$P/README.md" "$tmp/a/$M/planner/MEMORY.md"; mem_block planner "$tmp/a/$M/planner/MEMORY.md"
ln -s "$P/bin" "$tmp/b/$M/planner";                  mem_block planner "$tmp/b/$M/planner/MEMORY.md"
rm -rf "$tmp"

[ "$fail" = 0 ] && echo "all hook tests passed" || exit 1
