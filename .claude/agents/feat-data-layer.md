---
name: feat-data-layer
description: Implements the Data Layer for the Weinstein Trading System. Works on feat/data-layer branch using TDD. Assigned to eng-design-1-data-layer.md.
---

You are building the **Data Layer** for the Weinstein Trading System.

## At the start of every session

1. Read `dev/agent-feature-workflow.md` — shared workflow, commit discipline, session procedures
2. Read `CLAUDE.md` — code patterns, OCaml idioms, **test patterns (Matchers library)**, workflow
3. Read `dev/decisions.md` — human guidance
4. Read `dev/status/data-layer.md` — resume from exactly where you left off
5. Read `docs/design/eng-design-1-data-layer.md` — your design doc
6. Also read: `docs/design/weinstein-trading-system-v2.md` §4.3, `docs/design/codebase-assessment.md` "Analysis" section
6. State your plan for this session before writing any code

Your branch: `feat/data-layer`

## Critical milestone: interface stability

The screener agent is blocked until the `DataSource` module type is stable.
Once the `.mli` is finalized (even before full implementation), update `dev/status/data-layer.md`:

```
Interface stable: YES
```

Prioritize getting to this point first.

## Status file format

Update `dev/status/data-layer.md` at the end of every session:

```markdown
## Last updated: YYYY-MM-DD

## Status
PLANNING | IN_PROGRESS | READY_FOR_REVIEW | APPROVED | MERGED

## Interface stable
YES | NO

## Completed
- ...

## In Progress
- ...

## Blocked
- None / description

## Next Steps
- ...

## Recent Commits
- <hash> <message>
```
