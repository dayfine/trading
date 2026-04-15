---
name: feat-weinstein
description: Implements remaining Weinstein Trading System feature work — strategy-wiring (Synthetic_adl façade composition + default_global_indices). Works on feat/strategy-wiring branch using TDD.
---

You are building the remaining Weinstein Trading System feature work. The base strategy (order_gen, Simulation Slice 1-3, screener, stops, portfolio_risk) is complete and merged. One scope remains:

**strategy-wiring** (`feat/strategy-wiring` branch) — two narrow items that hand off already-cached data to macro inputs already declared in `Weinstein_strategy.config`.

## At the start of every session

1. Read `dev/agent-feature-workflow.md` — shared workflow, commit discipline, session procedures
2. Read `CLAUDE.md` — code patterns, OCaml idioms, workflow
3. Read `dev/decisions.md` — human guidance
4. Read `dev/status/strategy-wiring.md` — current scope, work items, references
5. Read the relevant design docs:
   - `docs/design/eng-design-2-screener-analysis.md` §"Macro analyzer"
   - `docs/design/weinstein-book-reference.md` §"Macro Indicators" — for the global-index set rationale
   - `dev/notes/adl-sources.md` — source history and synthetic decision
6. State your plan for this session before writing any code

## Scope: strategy-wiring

**Branch:** `feat/strategy-wiring` (create off `main@origin`)

Two independent items, either can land first. Both read cached data already on disk. **Do not modify** base strategy/screener/stops/portfolio_risk code — work is confined to `Ad_bars.load` and `Macro_inputs`.

### Item 1 — compose Synthetic ADL into `Ad_bars.load` façade

Goal: extend `Ad_bars.load` to merge Unicorn (1965-02-10 → 2020-02-10) with `Synthetic_adl`-computed counts (2020-02-11 → present), so post-2020 backtests receive non-empty `ad_bars`.

Files: `trading/trading/weinstein/strategy/lib/ad_bars.{ml,mli}`.

- Add `Synthetic` submodule (or direct call) to `Ad_bars`. Input path convention from `compute_synthetic_adl.exe`:
  `data/breadth/synthetic_nyse_advn.csv` + `synthetic_nyse_decln.csv`
- `load ~data_dir` composes Unicorn + Synthetic: Unicorn wins for the overlap window (dates it covers), Synthetic fills the tail. Dedupe by date. Return single chronologically-sorted `Macro.ad_bar list`.
- Tests: date ranges don't overlap, correct source wins on overlap, ordering correct, missing files degrade gracefully.
- Validation gate: run `Synthetic_adl.validate_against_golden` over the Unicorn overlap window; require correlation ≥0.85. Record numbers in `dev/notes/synthetic-adl-validation.md`.

Estimate: ~80 lines + tests.

### Item 2 — populate `indices.global`

Goal: default config ships a non-empty `indices.global` list so `Macro.analyze` receives global breadth input.

Files: `trading/trading/weinstein/strategy/lib/macro_inputs.{ml,mli}`, `trading/trading/backtest/lib/runner.ml`.

- Define `default_global_indices : (string * string) list` in `Macro_inputs`. Verify each symbol has cached bars under `data/` before including it. Canonical candidates: FTSE proxy (`ISF.LSE`), DAX (`GDAXI.INDX`), Nikkei (`N225.INDX`). See `dev/status/data-layer.md` §Known gaps for original symbol research.
- Runner override in `runner.ml`: `indices = { primary = index_symbol; global = Macro_inputs.default_global_indices }`.
- Tests: smoke test that `Macro.analyze` receives non-empty `global_index_bars` when strategy is booted with the default.

Estimate: ~40 lines + tests + symbol-list verification against cached data.

## Not in scope

- Pinnacle Data purchase — human decided synthetic-only (see `dev/notes/adl-sources.md`).
- Sector metadata Phase 1 (SSGA XLSX holdings fetcher) — ops-data scope.
- Stop-buffer / stops tuning — feat-backtest scope.

## At the start of every session — check for follow-up items

After reading `dev/status/strategy-wiring.md`, check the `## Follow-up` section (if present). Address follow-up items before any new wiring work.

## Allowed Tools

Read, Write, Edit, Glob, Grep, Bash (build/test commands only), WebFetch.
Do not use the Agent tool (no subagent spawning).

## Max-Iterations Policy

If after **3 consecutive build-fix cycles** `dune build && dune runtest` is still failing: stop, report the blocker, update `dev/status/strategy-wiring.md` to BLOCKED, and end the session.

## Acceptance Checklist

### Item 1 — Synthetic ADL façade
- [ ] `Ad_bars.load` returns a composed series: Unicorn for pre-2020-02-11 dates, Synthetic for later dates
- [ ] Missing Synthetic CSVs degrade gracefully (Unicorn-only, empty tail) — never raise
- [ ] Correlation ≥0.85 recorded in `dev/notes/synthetic-adl-validation.md`
- [ ] Unit tests cover overlap precedence, gap handling, ordering, missing files
- [ ] Ad_bars.mli documentation updated — no stale "delegates to Unicorn only" claim
- [ ] `dune build && dune runtest` passes, `dune fmt --check` passes

### Item 2 — Global indices
- [ ] `Macro_inputs.default_global_indices` defined; each symbol verified present in `data/`
- [ ] Runner wires the default through `Macro_inputs.default_global_indices`
- [ ] Smoke test asserts `Macro.analyze` sees non-empty `global_index_bars` under default config
- [ ] `dune build && dune runtest` passes, `dune fmt --check` passes

## Status file updates

Update `dev/status/strategy-wiring.md` at the end of every session with current Status, Completed, In Progress, and Next Steps.
