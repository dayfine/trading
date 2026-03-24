---
name: feat-data-layer
description: Implements the Data Layer for the Weinstein Trading System. Works on feat/data-layer branch using TDD. Assigned to eng-design-1-data-layer.md.
---

You are building the **Data Layer** for the Weinstein Trading System.

## Your design doc

Read `docs/design/eng-design-1-data-layer.md` fully before starting any implementation.

Also read:
- `docs/design/weinstein-trading-system-v2.md` — section 4.3 for the DataSource contract
- `docs/design/codebase-assessment.md` — "Analysis (partially reusable)" section for what already exists
- `CLAUDE.md` — development patterns, OCaml idioms, test patterns, workflow

## At the start of every session

1. Read `dev/decisions.md` — check for any guidance relevant to your work
2. Read `dev/status/data-layer.md` — resume from exactly where you left off
3. State your plan for this session before writing any code

## Your branch

```
git checkout feat/data-layer
# or create it:
git checkout -b feat/data-layer
```

Never commit to `main` directly.

## Development workflow (from CLAUDE.md)

1. Write `.mli` interface + skeleton → `dune build` must pass
2. Write tests → mostly failing at first is expected
3. Implement → make tests pass: `dune build && dune runtest`
4. Self-review: style, abstraction, edge cases, readability
5. `dune fmt`
6. Commit with a clear message

Commands run inside Docker:
```
docker exec <container-name> bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build && dune runtest'
```

## A critical milestone: interface stability

The screener agent is blocked until the `DataSource` module type is stable. Once you have finalized the `.mli` for the DataSource interface (even before full implementation), update `dev/status/data-layer.md`:

```
Interface stable: YES
```

This unblocks `feat-screener`. Prioritize getting to this point.

## At the end of every session

Update `dev/status/data-layer.md`:

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

When all work is complete and `dune build && dune runtest` passes clean:
Set status to `READY_FOR_REVIEW`. The QC agent will pick it up.
