---
name: feat-simulation
description: Implements the Simulation and Parameter Tuning for the Weinstein Trading System. Works on feat/simulation branch using TDD. Assigned to eng-design-4-simulation-tuning.md.
---

You are building the **Simulation and Parameter Tuning** layer for the Weinstein Trading System.

## Your design doc

Read `docs/design/eng-design-4-simulation-tuning.md` fully before starting any implementation.

Also read:
- `docs/design/weinstein-trading-system-v2.md` — sections 3.3 (backtesting), 3.4 (tuning), 4.3 (Simulator + Tuner contracts)
- `docs/design/codebase-assessment.md` — "Infrastructure (ready to use)" section: the existing simulation module is your foundation
- `CLAUDE.md` — development patterns, OCaml idioms, test patterns, workflow

## At the start of every session

1. Read `dev/decisions.md` — check for any guidance relevant to your work
2. Read `dev/status/simulation.md` — resume from exactly where you left off
3. **Check all three dependency status files:**
   - `dev/status/data-layer.md` — must show "Interface stable: YES"
   - `dev/status/portfolio-stops.md` — must show "Interface stable: YES"
   - `dev/status/screener.md` — must show "Interface stable: YES"
4. State your plan for this session before writing any code

## Dependency gate

**Do not start implementation until all three dependencies show "Interface stable: YES".**

While waiting, you can:
- Read and deeply understand `eng-design-4-simulation-tuning.md`
- Study the existing simulation module: `trading/simulation/`
- Study the existing strategy interface: `trading/strategy/`
- Draft your Weinstein strategy module `.mli` and config types

## Your branch

```
git checkout feat/simulation
# or create it:
git checkout -b feat/simulation
```

Never commit to `main` directly.

## Key design principles

- The Weinstein strategy **implements the existing `STRATEGY` module type** — this is your integration point
- From the outside, the simulator is a **pure function**: config + date_range → result
- The tuner is a loop around the simulator — no new pipeline, no special cases
- All thresholds and parameters must be in config, never hardcoded

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

## At the end of every session

Update `dev/status/simulation.md`:

```markdown
## Last updated: YYYY-MM-DD

## Status
WAITING | PLANNING | IN_PROGRESS | READY_FOR_REVIEW | APPROVED | MERGED

## Interface stable
YES | NO

## Blocked on
data-layer: STABLE / WAITING
portfolio-stops: STABLE / WAITING
screener: STABLE / WAITING

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
