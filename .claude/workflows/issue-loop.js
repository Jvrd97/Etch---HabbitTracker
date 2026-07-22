// issue-loop — closed-loop implement→review→verdict→iterate for ONE kanban issue.
//
// Что делает: берёт путь к issue-файлу, реализует его через TDD, прогоняет 2
// независимых ревью (стандарты кода + соответствие кодовой базе/архитектуре),
// сводит вердикт. Если REQUEST CHANGES — findings уходят обратно имплементеру,
// до maxRounds раундов. Возвращает вердикт + сводку диффа.
//
// Что НЕ делает (намеренно, human-in-the-loop): не коммитит, не двигает issue по
// lifecycle. Эти необратимые шаги остаются за человеком после просмотра вердикта.
//
// Запуск:
//   Workflow({ name: 'issue-loop',
//              args: { issue: 'issues/PHASE-01/issues/backlog/02-tracer-single-marker-recommendation.md',
//                      maxRounds: 3 } })

export const meta = {
  name: 'issue-loop',
  description: 'Closed loop: implement one issue via TDD, dual-review, iterate until approved or maxRounds',
  whenToUse: 'Автономно довести один AFK-тикет с уже готовыми acceptance до состояния "ревью пройдено", без ручного ре-промпта между шагами.',
  phases: [
    { title: 'Implement', detail: 'TDD red→green→refactor + feedback loops' },
    { title: 'Review', detail: 'standards reviewer + codebase-alignment reviewer, параллельно' },
    { title: 'Verdict', detail: 'свести оба ревью в APPROVE / REQUEST CHANGES' },
  ],
}

// args may arrive JSON-encoded as a plain string depending on the caller — normalize.
const _args = typeof args === 'string' ? JSON.parse(args) : args
const issuePath = _args?.issue
const maxRounds = _args?.maxRounds ?? 3
// optional model override for all agents in this loop (e.g. 'opus'); omit → inherit session model
const model = _args?.model
if (!issuePath) throw new Error('args.issue (path to issue .md) is required')

// --- schemas -----------------------------------------------------------------

const IMPLEMENT_SCHEMA = {
  type: 'object',
  required: ['summary', 'filesTouched', 'feedbackLoops', 'acceptanceCovered'],
  properties: {
    summary: { type: 'string', description: 'Что сделано, 1-3 предложения' },
    filesTouched: { type: 'array', items: { type: 'string' } },
    feedbackLoops: {
      type: 'object',
      required: ['lint', 'types', 'tests'],
      properties: {
        lint: { type: 'string', enum: ['pass', 'fail', 'n/a'] },
        types: { type: 'string', enum: ['pass', 'fail', 'n/a'] },
        tests: { type: 'string', enum: ['pass', 'fail', 'n/a'] },
      },
    },
    acceptanceCovered: { type: 'boolean', description: 'Все acceptance criteria закрыты?' },
    notes: { type: 'string' },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['verdict', 'blockers', 'warnings'],
  properties: {
    verdict: { type: 'string', enum: ['APPROVE', 'REQUEST_CHANGES', 'NEEDS_DISCUSSION'] },
    blockers: {
      type: 'array',
      items: {
        type: 'object',
        required: ['where', 'what', 'fix'],
        properties: {
          where: { type: 'string' }, what: { type: 'string' }, fix: { type: 'string' },
        },
      },
    },
    warnings: { type: 'array', items: { type: 'string' } },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['approved', 'reason', 'changeRequests'],
  properties: {
    approved: { type: 'boolean' },
    reason: { type: 'string' },
    changeRequests: {
      type: 'array',
      description: 'Конкретные правки для следующего раунда имплементации',
      items: { type: 'string' },
    },
  },
}

// --- prompts -----------------------------------------------------------------

function implementPrompt(round, changeRequests) {
  if (round === 1) {
    return `Apply the implement-issue skill (.claude/skills/implement-issue.md) to this issue: ${issuePath}

ЖЁСТКОЕ ПРАВИЛО ОКРУЖЕНИЯ (иначе зависнешь навсегда на permission-промпте):
- Bash-команды выполняй СТРОГО ПО ОДНОЙ, без '&&', без ';', без пайпов —
  составная команда не матчится ни одним allow-правилом.
- Работай в текущем рабочем каталоге: НЕ меняй cwd через cd, НЕ создавай
  git worktree, НЕ трогай чужие .claude/worktrees/*.
- Для команд из подкаталогов используй флаги вместо cd: 'uv run --directory <dir> ...',
  'git -C <dir> ...', 'bunx tsc -p <path>'.

Строгий TDD: red → green → refactor, по одному acceptance criterion за цикл.
После закрытия всех criteria прогони feedback loops (ruff/mypy/pytest для Python,
typecheck/lint/test для TS). Если красное — чини, не завершай.

Review tracking (CLAUDE.md §9): в каждый тронутый файл кода добавь header
[review:need-review] <ticket-id> + summary-строку.

НЕ коммить. НЕ двигай issue по папкам. Только реализуй и оставь рабочее дерево
с изменениями. Верни структурированный результат.`
  }
  return `Раунд ${round}. Предыдущая имплементация issue ${issuePath} завернута на ревью.
Bash-команды строго по одной (без '&&'/';'/пайпов), cwd не менять, worktree не создавать.
Внеси РОВНО эти правки, ничего сверх:

${changeRequests.map((c, i) => `${i + 1}. ${c}`).join('\n')}

После правок снова прогони feedback loops. TDD: если меняешь поведение — сначала
тест. НЕ коммить, НЕ двигай issue. Верни структурированный результат.`
}

const STANDARDS_PROMPT = `Ты reviewer (.claude/agents/reviewer.md). Отревью текущие изменения
рабочего дерева против стандартов проекта.

1. Возьми дифф: \`git --no-pager diff\` (незакоммиченные правки) + \`git --no-pager diff --stat\`.
2. Прочитай issue ${issuePath} — поняй intent и acceptance.
3. Проверь каждый файл против стандартов из своего агент-промпта (типы, no any,
   no silent except, no debug print, TDD-тесты осмысленные, и т.д.).
4. Прогони feedback loops если можешь и отметь их статус.

Верни структуру: verdict (APPROVE если 0 блокеров; REQUEST_CHANGES если есть),
blockers[], warnings[]. Если имплементация противоречит intent тикета — это BLOCKER,
даже если код чистый.`

const ALIGNMENT_PROMPT = `Ты reviewer соответствия КОДА архитектуре и существующей кодовой базе
(НЕ аудит доков — смотришь сам код). Изменения — в незакоммиченном дереве.

1. Дифф: \`git --no-pager diff\` + \`git --no-pager diff --stat\`.
2. Контекст архитектуры: прочитай issue ${issuePath} (его Module Map), CLAUDE.md §4
   (Architecture Constraints), и пер-сервисные README/ADRs.md рядом с тронутыми файлами.
3. Проверь именно ВПИСАННОСТЬ, не стиль:
   - Переиспользует ли существующие модули/паттерны, или дублирует уже имеющееся?
   - Уважает ли границы сервисов и ownership данных (user-data→Postgres/Redis,
     shared→Qdrant, LLM только через orchestration layer)?
   - Совпадают ли слои с соседним кодом (router→service→repo, DTO в ответах API,
     SQLAlchemy 2.0 Mapped[], async без блокирующего I/O в hot path)?
   - Нет ли скрытого coupling (общая таблица/модель между сервисами)?
   - Согласованы ли имена/термины с глоссарием и соседними модулями?
4. Дубликат уже существующей логики или нарушение границы сервиса = BLOCKER.

Верни структуру: verdict, blockers[] (where/what/fix), warnings[].`

function verdictPrompt(standards, alignment, impl) {
  return `Сведи два независимых ревью одной имплементации в финальный вердикт.

ИМПЛЕМЕНТАЦИЯ (само-отчёт):
${JSON.stringify(impl, null, 2)}

РЕВЬЮ СТАНДАРТОВ:
${JSON.stringify(standards, null, 2)}

РЕВЬЮ СООТВЕТСТВИЯ КОДОВОЙ БАЗЕ:
${JSON.stringify(alignment, null, 2)}

Правила:
- approved=true ТОЛЬКО если: оба ревью != REQUEST_CHANGES, ни одного блокера,
  acceptanceCovered=true, и все feedbackLoops != fail.
- Иначе approved=false, и в changeRequests[] выпиши конкретные атомарные правки
  (каждый блокер → одна правка с указанием файла), которые имплементер должен
  внести в следующем раунде. Без воды, исполнимые инструкции.`
}

// --- loop --------------------------------------------------------------------

log(`issue-loop: ${issuePath} (maxRounds=${maxRounds})`)

let changeRequests = []
let lastVerdict = null
let lastImpl = null
const history = []

for (let round = 1; round <= maxRounds; round++) {
  log(`— раунд ${round}/${maxRounds}: implement`)
  phase('Implement')
  const impl = await agent(implementPrompt(round, changeRequests), {
    label: `implement r${round}`,
    phase: 'Implement',
    schema: IMPLEMENT_SCHEMA,
    ...(model ? { model } : {}),
  })
  lastImpl = impl
  if (!impl) {
    history.push({ round, error: 'implement agent returned null' })
    break
  }

  log(`— раунд ${round}: dual review`)
  const [standards, alignment] = await parallel([
    () => agent(STANDARDS_PROMPT, { label: `review:standards r${round}`, phase: 'Review', schema: REVIEW_SCHEMA, ...(model ? { model } : {}) }),
    () => agent(ALIGNMENT_PROMPT, { label: `review:alignment r${round}`, phase: 'Review', schema: REVIEW_SCHEMA, ...(model ? { model } : {}) }),
  ])

  phase('Verdict')
  const verdict = await agent(verdictPrompt(standards, alignment, impl), {
    label: `verdict r${round}`,
    phase: 'Verdict',
    schema: VERDICT_SCHEMA,
    ...(model ? { model } : {}),
  })
  lastVerdict = verdict
  history.push({ round, impl, standards, alignment, verdict })

  if (verdict?.approved) {
    log(`✓ раунд ${round}: APPROVED`)
    break
  }
  changeRequests = verdict?.changeRequests ?? []
  log(`✗ раунд ${round}: REQUEST_CHANGES (${changeRequests.length} правок)`)
  if (round === maxRounds) log(`maxRounds исчерпан без аппрува — оставляю человеку`)
}

return {
  issue: issuePath,
  approved: !!lastVerdict?.approved,
  rounds: history.length,
  finalVerdict: lastVerdict,
  lastImplementation: lastImpl,
  // Next step для человека (вне петли): просмотреть дифф, при approved=true —
  // mv issue → in-review, закоммитить с Refs <ticket>; иначе разобрать changeRequests.
  history,
}
