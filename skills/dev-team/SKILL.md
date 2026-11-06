---
name: dev-team
description: Run a software task with a team of subagents - an Opus planner writes the plan, then Sonnet/Haiku agents implement, test, review and document it, in parallel where tasks are independent. Use when the user asks for /dev-team, "use the team", or a multi-step feature/refactor that benefits from planning plus parallel work.
---

# Dev team workflow

You are the controller. You plan with the planner, dispatch work, gate it with reviews, make rulings, and keep the ledger. You do not write production code yourself: to change code, resume the implementer (or dispatch a new one).

## Team (`~/.claude/agents`)
| agent | default model | job |
|---|---|---|
| `planner` | opus | plan with tasks, waves, risk, model per task (read-only) |
| `scout` | haiku | lookups - use instead of general-purpose agents |
| `implementer` | sonnet (haiku for mechanical tasks) | one task per dispatch |
| `test-engineer` | sonnet | tests, TDD RED evidence |
| `debugger` | sonnet | unknown-cause failures |
| `reviewer` | sonnet (opus for the final review of large/risky diffs) | spec + quality gate (read-only) |
| `security-reviewer` | opus | only for security-sensitive tasks (read-only) |
| `docs-writer` | haiku | docs |

**Always pass `model` explicitly on every Agent call.** An omitted model inherits this session's (usually the most expensive) model. Use the tier the planner suggested for each task.

## Files (in the target repo, under `.claude/plans/`)
- `<slug>.md` - the plan as returned by the planner.
- `<slug>/T<n>.md` - one brief per task: the task block from the plan + the plan's Context section + any rulings that affect it.
- `<slug>.progress.md` - the ledger. Update it after every step (the dev-team-view pane reads it live). **After a compaction, re-read the ledger before doing anything and never re-dispatch a task marked complete.** Keep exactly this format:

```markdown
# dev-team: <short title>
plan: .claude/plans/<slug>.md
base: <BASE commit sha>
status: planning | running | reviewing | done | stopped
wave: <current>/<total>
updated: <YYYY-MM-DD HH:MM>

| task | wave | agent | model | status | review | branch | note |
|------|------|-------|-------|--------|--------|--------|------|
| T1 | 1 | implementer | sonnet | pending | - | - | |

## Rulings
- Ruling: <what> — <why> — <cost if wrong>

## Memory
- planner +2
```
`status` per task: `pending`, `running`, `fixing r<n>`, `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `BLOCKED`. `review`: `-`, `✅`, `❌ r<n>`, `parked <n>`. `branch`: the worktree branch or `-`. Set `status: done` (or `stopped`) at the end.
Add `.claude/plans/` and `.claude/agent-memory-local/` to `.git/info/exclude` (unless the project tracks them).

## Agent memory
planner, reviewer, security-reviewer, implementer, debugger and test-engineer keep notes in `.claude/agent-memory-local/<agent>/MEMORY.md`, which is loaded automatically when they start. The read-only agents can write only that one file (a hook blocks everything else). scout and docs-writer have no memory.
- Worktree agents write their notes inside the temporary worktree. **After each wave, before the worktrees are removed, run `fleet memory sync <repo>`** to copy new note lines into the main repo's files.
- Don't paste memory contents into dispatches; each agent already sees its own notes.

## Steps
1. **Plan.** Dispatch `planner` with the goal and the user's constraints. Skip only for a single obvious change. Save the plan, write the briefs, start the ledger with `BASE=$(git rev-parse HEAD)`.
2. **Confirm.** Show the user the goal, tasks, waves and open questions in a few lines. Wait for approval unless they already said go.
3. **Execute wave by wave.** Launch all tasks of a wave in ONE message so they run in parallel. Pass each agent its brief path (tell it to read it) - never the whole plan or earlier conversation.
   - 2+ code-changing tasks in a wave (git repo): give each `isolation: "worktree"`. Record each task's branch in the ledger. After the wave, merge each branch with `git merge --no-ff`, resolve trivial conflicts, send real conflicts to an `implementer`, then run the test suite on the merged result.
   - A single task runs in the main checkout.
4. **Handle status.**
   - `DONE` → task review.
   - `DONE_WITH_CONCERNS` → task review, with the concerns listed in the reviewer prompt.
   - `NEEDS_CONTEXT` → answer (use `scout` if needed), then resume the same agent with SendMessage.
   - `BLOCKED` → fix the brief, split the task, escalate the model, or ask the user if it needs a human decision.
5. **Task review (every task).** Dispatch `reviewer` with the brief, the agent's report, and the range `<task base>..<task head>` (record the task base before dispatch; never use `HEAD~1`). Copy binding constraints from the plan verbatim. Never tell the reviewer what not to flag. Security-sensitive tasks also go to `security-reviewer`.
6. **Fix loop.** On ❌ spec, any Critical/Important, or a confirmed ⚠️: rounds 1-2 resume the same implementer with the findings; round 3 dispatches a fresh implementer on `opus`. After round 3, park remaining findings as a ruling, mark the task complete with "N parked", and tell the user. Each fix round gets a scoped re-review of the fix diff.
7. **Final review.** After the last wave: `test-engineer` (if tests weren't covered), the full test suite, then one whole-branch `reviewer` pass over `BASE..HEAD` (opus if the diff is large or risky). Apply one fix wave.
8. **Docs.** If behavior or interfaces changed, dispatch `docs-writer`.
9. **Promote learnings.** Read the agents' MEMORY.md files. Lines that have become stable project rules (conventions, required commands, "never do X") belong in CLAUDE.md: show the user the proposed CLAUDE.md diff, apply it only on their OK, then delete the promoted lines from memory. If a memory file is near 150 lines, ask that agent to prune it next time.
10. **Report.** What was done, test result, review verdicts, parked findings, rulings, and which agents updated memory. Do not push or open PRs unless the user asked.

## Rulings and when to stop
Decide conflicts and ambiguities yourself and log them: `Ruling: <what> — <why> — <cost if wrong>`. Stop and ask the user only for: destructive or irreversible operations, security-sensitive decisions, pushing/merging to a shared branch, or a plan so broken that every way forward is a guess.

## Red flags
- Dispatching without a ledger, or re-dispatching completed work after compaction.
- An Agent call without `model`.
- Pasting earlier task summaries or the whole plan into a dispatch.
- Two parallel tasks touching the same file, or parallel code tasks without worktree isolation.
- Skipping the task review or the re-review after a fix.
- Reviewing `HEAD~1` instead of the task's real range.
- The controller editing code instead of resuming the implementer.
- Using a general-purpose agent where `scout` would do.
