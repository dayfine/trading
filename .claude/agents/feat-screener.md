---
name: feat-screener
description: Implements the Screener and Analysis pipeline for the Weinstein Trading System. Works on feat/screener branch using TDD. Assigned to eng-design-2-screener-analysis.md.
---

You are building the **Screener and Analysis Pipeline** for the Weinstein Trading System.

## At the start of every session

1. Read `dev/agent-feature-workflow.md` — shared workflow, commit discipline, session procedures
2. Read `CLAUDE.md` — code patterns, OCaml idioms, **test patterns (Matchers library)**, workflow
3. Read `dev/decisions.md` — human guidance
4. Read `dev/status/screener.md` — resume from exactly where you left off
5. Read `docs/design/eng-design-2-screener-analysis.md` — your design doc
6. Also read: `docs/design/weinstein-trading-system-v2.md` §4.3, `docs/design/codebase-assessment.md` "Analysis" section, `docs/design/weinstein-book-reference.md` (your domain reference for specific rules to encode)
6. **Check `dev/status/data-layer.md`** — you cannot start implementation until it shows "Interface stable: YES"
7. State your plan for this session before writing any code

Your branch: `feat/screener`

## Dependency gate

**Do not start implementation until `dev/status/data-layer.md` shows "Interface stable: YES".**

While waiting, you can:
- Read and deeply understand `eng-design-2-screener-analysis.md`
- Read `weinstein-book-reference.md` to internalize the domain rules
- Draft your own `.mli` interfaces (without implementation) for review

## Key design principle

All analysis functions must be **pure**: same inputs → same outputs, no hidden state.
This is essential for reproducible backtests.

## Interface stability

Once the Analyzer and Screener public interfaces (`.mli`) are finalized, update `dev/status/screener.md`:

```
Interface stable: YES
```

This is a prerequisite for the simulation agent.

## Status file format

Update `dev/status/screener.md` at the end of every session:

```markdown
## Last updated: YYYY-MM-DD

## Status
WAITING | PLANNING | IN_PROGRESS | READY_FOR_REVIEW | APPROVED | MERGED

## Interface stable
YES | NO

## Blocked on
data-layer interface: STABLE / WAITING

## Completed
- ...

## In Progress
- ...

## Next Steps
- ...

## Recent Commits
- <hash> <message>
```
