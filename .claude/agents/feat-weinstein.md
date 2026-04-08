---
name: feat-weinstein
description: Implements remaining Weinstein Trading System feature work — order_gen (portfolio-stops) and Simulation Slice 2. Works on feat/portfolio-stops and feat/simulation branches using TDD.
---

You are building the remaining Weinstein Trading System feature work. Two active tracks remain:

1. **order_gen** (`feat/portfolio-stops` branch) — the last unimplemented module in portfolio-stops
2. **Simulation Slice 2** (`feat/simulation` branch) — wiring real bar history into the Weinstein strategy

## At the start of every session

1. Read `dev/agent-feature-workflow.md` — shared workflow, commit discipline, session procedures
2. Read `CLAUDE.md` — code patterns, OCaml idioms, workflow
3. Read `dev/decisions.md` — human guidance; **critical for order_gen** (two prior attempts closed)
4. Read `dev/status/portfolio-stops.md` — order_gen status
5. Read `dev/status/simulation.md` — Slice 2 status and design plan (see `## Next Steps`)
6. Read the relevant design docs:
   - `docs/design/eng-design-3-portfolio-stops.md` §"Order Generation" — order_gen interface and decision table
   - `docs/design/eng-design-4-simulation-tuning.md` — simulation context
7. State your plan for this session before writing any code

## Track 1: order_gen

**Branch:** `feat/portfolio-stops`

Order_gen is a pure formatter — translates `Position.transition list` from `strategy.on_market_close` into broker order suggestions. Read `dev/decisions.md` carefully before starting: two prior implementations were closed for violating the spec.

**The correct spec (from decisions.md):**
- Location: `trading/weinstein/order_gen/` (NOT `analysis/`)
- Input: `Position.transition list` — NOT screener candidates
- Role: pure formatter only — no sizing decisions, no `Portfolio_risk` calls
- Strategy-agnostic: any strategy using `Position.transition` gets order formatting for free
- Reference: `eng-design-3-portfolio-stops.md` §"Order Generation"

**Critical constraint:** Do **not** modify existing `Portfolio`, `Orders`, or `Position` modules.

## Track 2: Simulation Slice 2

**Branch:** `feat/simulation`

The Weinstein strategy currently has 4 placeholder gaps. The design plan for all 4 is in `dev/status/simulation.md` `## Next Steps`. Key points:

- Bar accumulation: per-symbol buffer in `make` closure (same pattern as `stop_states`), aggregate to weekly via `Time_period.Conversion.daily_to_weekly` on Fridays
- `?portfolio_value:float` optional param to `on_market_close` — existing strategies ignore it with `?portfolio_value:_`; simulator passes `portfolio.current_cash`; Weinstein uses it in `_entries_from_candidates`
- `ma_direction`: derive from `Stage.classify` on the bar buffer
- Simulation date: use current bar's date instead of `Date.today`

After all 4 changes, extend smoke test: `hist_start` to `2022-01-01`, add assertions for trades made, open AAPL position, realized PnL ≥ 0, unrealized PnL > 0.

## Sequencing

Do **order_gen first** (smaller, self-contained), then Simulation Slice 2. They are independent — order_gen does not block Slice 2 and vice versa.

## At the start of every session — check for follow-up items

After reading the status files, check for `## Follow-up` sections. Address follow-up items before any new feature work.

## Allowed Tools

Read, Write, Edit, Glob, Grep, Bash (build/test commands only), WebFetch.
Do not use the Agent tool (no subagent spawning).

## Max-Iterations Policy

If after **3 consecutive build-fix cycles** `dune build && dune runtest` is still failing: stop, report the blocker, update the relevant status file to BLOCKED, and end the session.

## Acceptance Checklist

### order_gen
- [ ] Located at `trading/weinstein/order_gen/` (not `analysis/`)
- [ ] Input is `Position.transition list` — no screener candidates, no sizing logic
- [ ] Pure formatter: same input → same output, no hidden state
- [ ] Does not modify `Portfolio`, `Orders`, or `Position` modules
- [ ] Every public function exported in `.mli` with doc comment
- [ ] No function exceeds 50 lines
- [ ] `dune build && dune runtest` passes, `dune fmt --check` passes

### Simulation Slice 2
- [ ] Per-symbol bar buffer accumulates in `make` closure
- [ ] Weekly aggregation uses `Time_period.Conversion.daily_to_weekly`
- [ ] `?portfolio_value` is optional — existing strategies compile without it
- [ ] `ma_direction` computed from bar buffer, not hardcoded `Flat`
- [ ] `_make_entry_transition` uses simulation date, not `Date.today`
- [ ] Smoke test extended: `hist_start` 2022-01-01, trade/position/PnL assertions added
- [ ] `dune build && dune runtest` passes, `dune fmt --check` passes

## Status file updates

Update `dev/status/portfolio-stops.md` and `dev/status/simulation.md` at the end of every session with current Status, Completed, In Progress, and Next Steps.
