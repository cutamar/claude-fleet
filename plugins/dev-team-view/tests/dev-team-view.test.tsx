import { expect, test } from 'claude-code/testing'

import { parseLedger, summary } from '../hooks/register'

const LEDGER = `# dev-team: Add --version flag
plan: .claude/plans/version-flag.md
base: 8d59750abc
status: running
wave: 2/3
updated: 2026-11-07 14:03

| task | wave | agent | model | status | review | branch | note |
|------|------|-------|-------|--------|--------|--------|------|
| T1 | 1 | implementer | haiku | DONE | ✅ | - | flag added |
| T2 | 2 | test-engineer | sonnet | running | - | worktree-agent-a1 | |
| T3 | 2 | implementer | sonnet | DONE_WITH_CONCERNS | ❌ r1 | worktree-agent-b2 | README row |

## Rulings
- Ruling: print bare version — user asked — low

## Memory
- planner +2
`

const run = parseLedger('version-flag.progress.md', LEDGER)
const seeded = (value: unknown) => () => ({ value: { value, version: 1 } })

const PANE = {
  plugin: 'dev-team-view', component: 'Pane', requestId: 'dev-team-view',
  props: {
    title: 'dev-team', isFocused: false, bodyColumns: 60, placement: 'dock',
    scroll: { offset: 0, bodyRows: 30 }, view: {},
  },
} as const

const BAND = {
  plugin: 'dev-team-view', component: 'AbovePrompt', requestId: 'band',
  props: {
    hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 100,
    scroll: { offset: 0, bodyRows: 10 }, view: {},
  },
} as const

test('parses the ledger format', async () => {
  expect(run.title).toBe('Add --version flag')
  expect(run.status).toBe('running')
  expect(run.wave).toBe('2/3')
  expect(run.tasks.length).toBe(3)
  expect(run.tasks[2]?.status).toBe('DONE_WITH_CONCERNS')
  expect(run.rulings.length).toBe(1)
  expect(summary(run)).toBe('dev-team: Add --version flag · wave 2/3 · 1 running · 1 need fixes · 2/3 done')
})

test('the pane shows tasks grouped by wave, on every surface', async ($, on) => {
  on('state.get', (_, e) => (e.key === 'run' ? seeded({ shape: 'run-1', value: run })() : seeded('')()))
  for (const surface of ['terminal', 'desktop', 'vscode', 'mobile'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /^Wave 2$/ }))?.text).toBe('Wave 2')
    expect((await ui.find({ type: 'Text', text: /README row/ }))?.text).toContain('implementer/sonnet')
    expect((await ui.find({ type: 'Text', text: /^Rulings/ }))?.text).toContain('print bare version')
    await ui.unmount()
  }
})

test('the pane says when there is no run', async ($, on) => {
  on('state.get', seeded({ shape: 'run-1', value: null }))
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await ui.find({ type: 'Text' }))?.text).toBe('No /dev-team run in this project yet.')
  await ui.unmount()
})

test('the band shows the summary while a run is active', async ($, on) => {
  on('state.get', (_, e) => (e.key === 'run' ? seeded({ shape: 'run-1', value: run })() : seeded('')()))
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /^dev-team:/ }))?.text).toContain('1 need fixes')
  await ui.unmount()
})

test('the band yields once the run is done', async ($, on) => {
  on('state.get', (_, e) => (e.key === 'run' ? seeded({ shape: 'run-1', value: { ...run, status: 'done' } })() : seeded('')()))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Text' }))?.text).toBe('engine')
  await ui.unmount()
})
