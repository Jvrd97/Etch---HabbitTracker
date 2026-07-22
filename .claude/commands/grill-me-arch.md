---
description: "Architecture-level grilling for system design questions affecting multiple services. Socratic dialogue about bounded contexts, service boundaries, transports, and trade-offs. Output saved to brain-dumps/architecture/."
---

Apply the `software-architect` skill (adopt that role) and the `architecture-grill` skill (follow the phase structure).

You stay in the main conversation context — this is an interactive grilling session, not a sub-agent call. The user sees your full reasoning and can guide phases.

## Pre-flight check

Before grilling starts, verify:

1. **Specific question exists**: $ARGUMENTS or recent context should contain a concrete architectural question (not just "design something")
2. **Existing state read**: glance at `docs/current/architecture/` if exists (`current` = symlink to active phase), `docs/architecture-2.0/` if older spec exists
3. **Out-of-scope clear**: what is NOT being decided this session

If $ARGUMENTS is empty or vague:
- Ask user: "What architectural question are we grilling? Something like:
  - 'Should we split service X?'
  - 'How should A and B communicate?'
  - 'Who owns entity Y?'
  - 'Should we adopt pattern Z here?'"

## Process

Following `architecture-grill` skill phases:

1. **Phase 1 — Domain Discovery** (10-20 questions): bounded contexts, domain events, business problem
2. **Phase 2 — Service decomposition** (15-25 questions): why these services, where boundaries are, what fits where
3. **Phase 3 — Data ownership** (10-15 questions): source of truth per entity, read patterns, consistency
4. **Phase 4 — Transports** (15-20 questions): sync vs async, retries, idempotency, failure modes
5. **Phase 5 — Cross-cutting** (10-15 questions): auth, observability, schema evolution, PII
6. **Phase 6 — Trade-offs** (5-10 questions): what's hard to change later, what we deliberately don't do

Between phases — DRAW interim Mermaid C4 diagrams using `c4-diagrams` skill. Diagrams surface issues prose hides.

## Pre-decisions if needed

If a question blocks progress (e.g., "should we use Kafka or HTTPX?"):
- Suggest pausing grilling
- Run `/explain-and-record` (or similar research session) to resolve
- Return with a decision

Otherwise grilling will loop on bikeshed questions.

## Multi-session handling

Big architecture grillings should span 2-3 sessions:
- Session 1: Phases 1-3 (domain + services + ownership)
- Session 2: Phases 4-5 (transports + cross-cutting) — after `/clear` for fresh context
- Session 3: Phase 6 (trade-offs) + draft architecture artifact

Between sessions, write partial state to `brain-dumps/architecture/<date>-<topic>-arch-grill-WIP.md` so next session can pick up.

## Output

After grilling complete (all 6 phases done), save artifact to `brain-dumps/architecture/<YYYY-MM-DD>-<topic-slug>-arch-grill.md`:

```markdown
# Architecture Grilling: <Topic> — <Date>

## Domain context
[business problem, key constraints]

## Bounded contexts identified
[list with one-liner each]

## Services proposed
[table: service / owns / reads / justification]

## Transports decided
[table: from / to / type / failure mode]

## Cross-cutting decisions
[bullet list per concern]

## Trade-offs explicitly accepted
[what we gain, what we give up]

## Pre-decisions for ADRs
[list of decisions that need ADRs in /write-architecture]

## Interim diagrams
[Mermaid C4 blocks drawn during session]

## Open questions for next session
[what we deferred]
```

## After grilling — what comes next

Tell user:
- "Grilling complete. Artifact saved to brain-dumps/architecture/<file>"
- "Next steps:"
  - "1. Review artifact, confirm decisions match your understanding"
  - "2. If issues — re-grill specific phases via /grill-me-arch <focus>"
  - "3. If aligned — run /write-architecture to produce the document set"
  - "4. After writing — /architecture-review to audit consistency"

Don't auto-write architecture. User must confirm grilling is complete first.

## When NOT to use this

- Single-service questions → use `/grill-me` (regular PRD grilling)
- Implementation details → use `/grill-me`
- "How does X work currently?" → use `/explain-and-record` on existing docs
- Quick "should we A or B?" with no surrounding architecture impact → just answer, don't grill
