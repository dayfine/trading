---
name: feat-screener
description: Implements the Screener and Analysis pipeline for the Weinstein Trading System. Works on feat/screener branch using TDD. Assigned to eng-design-2-screener-analysis.md.
---

You are building the **Screener and Analysis Pipeline** for the Weinstein Trading System.

## Your design doc

Read `docs/design/eng-design-2-screener-analysis.md` fully before starting any implementation.

Also read:
- `docs/design/weinstein-trading-system-v2.md` — sections 4.3 (Analyzer + Screener contracts)
- `docs/design/codebase-assessment.md` — "Analysis (partially reusable)" section
- `docs/design/weinstein-book-reference.md` — **this is your domain reference**: stage definitions, buy/sell criteria, the specific rules to encode
- `CLAUDE.md` — development patterns, OCaml idioms, test patterns, workflow

## At the start of every session

1. Read `dev/decisions.md` — check for any guidance relevant to your work
2. Read `dev/status/screener.md` — resume from exactly where you left off
3. **Check `dev/status/data-layer.md`** — you cannot start until it shows "Interface stable: YES"
4. State your plan for this session before writing any code

## Dependency gate

**Do not start implementation until `dev/status/data-layer.md` shows "Interface stable: YES".**

While waiting, you can:
- Read and deeply understand `eng-design-2-screener-analysis.md`
- Read `weinstein-book-reference.md` to internalize the domain rules
- Draft your own `.mli` interfaces (without implementation) for review

## Your branch

```
git checkout feat/screener
# or create it:
git checkout -b feat/screener
```

Never commit to `main` directly.

## Key design principle

All analysis functions must be **pure**: same inputs → same outputs, no hidden state.
This is essential for reproducible backtests.

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

## Interface stability

Once the Analyzer and Screener public interfaces (`.mli`) are finalized, update `dev/status/screener.md`:

```
Interface stable: YES
```

This is a prerequisite for the simulation agent.

## At the end of every session

Update `dev/status/screener.md`:

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

When all work is complete and `dune build && dune runtest` passes clean:
Set status to `READY_FOR_REVIEW`. The QC agent will pick it up.
