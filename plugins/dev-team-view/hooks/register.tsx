import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Run, Task } from '../types'

const PANE = 'dev-team-view'
const POLL_MS = 3000
const ENDED = new Set(['done', 'stopped'])

// Bump the shape tag when Run's fields change, so a value stored by an
// earlier version is declined instead of drawn wrong.
const run = atom({ plugin: 'dev-team-view', key: 'run' } as const, null, { shape: 'run-1' })
// The ledger file whose band the person hid ('' = none hidden).
const hiddenFor = atom({ plugin: 'dev-team-view', key: 'hiddenFor' } as const, '')

/** Parses a ledger written in the format the dev-team skill defines. */
export function parseLedger(file: string, text: string): Run {
  const result: Run = {
    file, title: file.replace(/\.progress\.md$/, ''), status: 'running', wave: '',
    base: '', updated: '', tasks: [], rulings: [], memory: [], others: 0,
  }
  let section = ''
  for (const raw of text.split('\n')) {
    const line = raw.trim()
    const heading = line.match(/^#\s+(?:dev-team:\s*)?(.+)$/)
    if (heading?.[1] && section === '') { result.title = heading[1]; continue }
    const sub = line.match(/^##\s+(.+)$/)
    if (sub?.[1]) { section = sub[1].toLowerCase(); continue }
    if (section === '') {
      const kv = line.match(/^(status|wave|base|updated):\s*(.*)$/i)
      if (kv?.[1] !== undefined && kv[2] !== undefined) {
        const key = kv[1].toLowerCase() as 'status' | 'wave' | 'base' | 'updated'
        result[key] = key === 'status' ? kv[2].trim().toLowerCase() : kv[2].trim()
      }
    }
    if (/^\|\s*T\d/.test(line)) {
      const c = line.replace(/^\||\|$/g, '').split('|').map(s => s.trim())
      result.tasks.push({
        id: c[0] ?? '', wave: c[1] ?? '', agent: c[2] ?? '', model: c[3] ?? '',
        status: c[4] ?? '', review: c[5] ?? '', branch: c[6] ?? '', note: c[7] ?? '',
      })
      continue
    }
    if (line.startsWith('- ') && section.startsWith('ruling')) result.rulings.push(line.slice(2))
    if (line.startsWith('- ') && section.startsWith('memory')) result.memory.push(line.slice(2))
  }
  return result
}

const isDone = (t: Task) => /^done/i.test(t.status)
const isStuck = (t: Task) => /^(blocked|needs_context)/i.test(t.status)
const isActive = (t: Task) => /^(running|fixing|review)/i.test(t.status)
const needsFix = (t: Task) => t.review.includes('❌') || /fix/i.test(t.review)

export function summary(r: Run): string {
  const parts = [`dev-team: ${r.title}`]
  if (r.wave) parts.push(`wave ${r.wave}`)
  const active = r.tasks.filter(isActive).length
  const stuck = r.tasks.filter(isStuck).length
  const fixes = r.tasks.filter(needsFix).length
  if (active) parts.push(`${active} running`)
  if (fixes) parts.push(`${fixes} need fixes`)
  if (stuck) parts.push(`${stuck} blocked`)
  parts.push(`${r.tasks.filter(isDone).length}/${r.tasks.length} done`)
  return parts.join(' · ')
}

function statusColor(status: string): string {
  if (/^done_with/i.test(status)) return 'warning'
  if (/^done/i.test(status)) return 'success'
  if (/^(blocked)/i.test(status)) return 'error'
  if (/^needs_context/i.test(status)) return 'warning'
  if (/^(running|fixing|review)/i.test(status)) return 'claude'
  return 'inactive'
}

function reviewColor(review: string): string {
  if (review.includes('✅')) return 'success'
  if (review.includes('❌') || /fix/i.test(review)) return 'error'
  if (/park|⚠/i.test(review)) return 'warning'
  return 'inactive'
}

// Module state: starts over on a reload, which only re-reads the ledger.
let lastText = ''
let lastStatus = ''
let openedFor = ''

async function refresh($: EngineInterface) {
  const dir = `${await $.session.root()}/.claude/plans`
  const entries = (await $.fs.exists(dir)) ? await $.fs.list(dir) : []
  const ledgers = entries
    .filter(f => f.kind === 'file' && f.name.endsWith('.progress.md'))
    .sort((a, b) => b.mtimeMs - a.mtimeMs)
  if (ledgers.length === 0) {
    if (lastText !== '') { lastText = ''; await update($, run, () => null) }
    return
  }
  const parsed: Run[] = []
  for (const f of ledgers.slice(0, 10)) {
    const text = await $.fs.read(`${dir}/${f.name}`).catch(() => '')
    parsed.push(parseLedger(f.name, text))
  }
  const current = parsed.find(r => !ENDED.has(r.status)) ?? parsed[0]
if (current === undefined) return
  current.others = parsed.filter(r => r !== current && !ENDED.has(r.status)).length
  const signature = JSON.stringify(current)
  if (signature === lastText) return
  lastText = signature
  await update($, run, () => current)

  const isLive = !ENDED.has(current.status)
  if (isLive && openedFor !== current.file) {
    openedFor = current.file
    void $.ui.open({ id: PANE, title: 'dev-team' })
  }
  if (lastStatus && !ENDED.has(lastStatus) && ENDED.has(current.status)) {
    $.ui.toast(`dev-team run ${current.status}: ${current.title}`)
  }
  lastStatus = current.status
}


export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'dev-team-view',
      description: 'Show live /dev-team progress for this project in a pane',
    })
    void refresh($).catch(() => undefined)
    $.clock.every(POLL_MS, () => { void refresh($).catch(() => undefined) })
    return next(e)
  })

  on('command.run', { command: 'dev-team-view' }, async $ => {
    await refresh($).catch(() => undefined)
    await $.ui.open({ id: PANE, title: 'dev-team' })
    await update($, hiddenFor, () => '')
    const r = await read($, run)
    return { text: r ? summary(r) : 'No /dev-team run in this project yet.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const r = await read($, run)
    if (r === null) {
      return (
        <Box flexDirection="column">
          <Text dimColor>No /dev-team run in this project yet.</Text>
          <Text dimColor>Progress appears here while /dev-team runs.</Text>
        </Box>
      )
    }
    const waves = [...new Set(r.tasks.map(t => t.wave))]
    const lastRuling = r.rulings.at(-1)
    return (
      <Box flexDirection="column">
        <Text bold wrap="truncate">{r.title}</Text>
        <Text dimColor wrap="truncate">
          {[r.status, r.wave && `wave ${r.wave}`, r.base && `base ${r.base.slice(0, 7)}`, r.updated]
            .filter(Boolean).join(' · ')}
        </Text>
        {waves.map(w => (
          <Box flexDirection="column" key={`w${w}`}>
            <Text color="subtle"> </Text>
            <Text color="subtle">Wave {w}</Text>
            {r.tasks.filter(t => t.wave === w).map(t => (
              <Box flexDirection="row" key={t.id}>
                <Text>{t.id.padEnd(4)} </Text>
                <Text color={statusColor(t.status)}>{(t.status || 'pending').padEnd(10)} </Text>
                <Text color={reviewColor(t.review)}>{(t.review || '-').padEnd(4)} </Text>
                <Text dimColor wrap="truncate">
                  {[t.agent, t.model].filter(Boolean).join('/')}{t.note ? ` · ${t.note}` : ''}
                </Text>
              </Box>
            ))}
          </Box>
        ))}
        {r.tasks.length === 0 && <Text dimColor>Planning…</Text>}
        <Text> </Text>
        <Text dimColor wrap="truncate">
          Rulings: {r.rulings.length}{lastRuling ? ` · last: ${lastRuling}` : ''}
        </Text>
        {r.memory.length > 0 && (
          <Text dimColor wrap="truncate">Memory: {r.memory.join(', ')}</Text>
        )}
        {r.others > 0 && <Text color="warning">+{r.others} other active run(s) in .claude/plans</Text>}
      </Box>
    )
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const r = await read($, run)
    if (e.props.hasSurvey || r === null || ENDED.has(r.status) || (await read($, hiddenFor)) === r.file) {
      return next(e)
    }
    const { Box, Button, Text } = $.ui.resolve(e)
    const stuck = r.tasks.some(isStuck) || r.tasks.some(needsFix)
    return (
      <Box flexDirection="row">
        <Text color={stuck ? 'warning' : 'claude'} wrap="truncate">{summary(r)} </Text>
        <Button key="open" label="Open" onPress={() => $.ui.open({ id: PANE, title: 'dev-team' })} />
        <Text> </Text>
        <Button key="hide" label="Hide" onPress={() => update($, hiddenFor, () => r.file)} />
      </Box>
    )
  })
}
