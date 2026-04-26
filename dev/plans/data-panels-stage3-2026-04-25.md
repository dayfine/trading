# Plan: data-panels Stage 3 — collapse Tiered Friday cycle, delete Bar_history (2026-04-25)

## Status

IN_PROGRESS. PR 3.1 (#567) + PR 3.2 (#569) merged. PR 3.3 in flight.
PR 3.4 pending.

**Post-PR-3.2 spike finding (2026-04-25):** Panel mode peak RSS at
N=292 T=6y bull-crash = **3.47 GB** (pre-3.2 Legacy 1.87 GB / Tiered
3.74 GB; projection < 800 MB). The structural Bar_history deletion
landed (Tiered → Panel: -7%, the +95% gap is gone), but the absolute
RSS thesis hasn't materialized. Top hypothesis: every reader site
still rebuilds `Daily_price.t list` from `Bar_panels` per tick. Stage
2's bar-list-shaped wrappers are the source. See
`dev/notes/panels-rss-spike-2026-04-25.md` for full analysis.

Implications:
- **PR 3.3 + 3.4 still safe to land** — they delete dead code
  (Tiered, bar_loader, Legacy) and don't affect Panel-mode RSS.
- **Stage 4 scope expanded** to call out the callback-through-runner
  wiring as the load-bearing perf gate. See master plan §"Stage 4".
- **Plan §Decision point applies** post-Stage-4: if the re-run spike
  is still > 1 GB, abort migration and memtrace.

## Context

Stage 2 (PRs #558-#565) reshaped six callees (`Stage`, `Rs`,
`Stock_analysis`, `Sector`, `Macro`, `Weinstein_stops`) into
`callbacks_from_bars` form and added `Bar_reader` polymorphic
abstraction over `Bar_history` (Tiered) | `Bar_panels` (Panel). PR-H
deferred the runner-level `~bar_panels` wiring + Bar_history deletion
to Stage 3.

**Load-bearing finding (from PR-H):** wiring `~bar_panels` into
`Panel_runner._build_strategy` produces 5 vs 3 trade divergence on
bull-2019h2 fixture. Tiered seeds `Bar_history` incrementally per
Friday Full-tier promote (not-yet-promoted symbols return `[]`);
`Bar_panels` is fully populated upfront from CSV. Stage 3 collapses
the Tiered cycle so only the upfront-load mode survives.

## Scope (per columnar plan §Stage 3)

After Stage 3:
- `loader_strategy = Panel` only (delete `Tiered | Legacy`)
- No `Bar_history`, no `Bar_loader` tiers, no Friday cycle, no
  `Shadow_screener`
- `Trace.Phase.t` loses `Promote_metadata|Promote_summary|Promote_full|Demote`
- `Bar_reader` collapses to thin wrapper over `Bar_panels` (or inlined)
- `bars_for_volume_resistance` transitional param dropped if Volume +
  Resistance reshape lands in parallel; otherwise carried into Stage 4

## PR breakdown

### PR 3.1 — Wire `~bar_panels` + Panel-goldens parity gate (~300 LOC)

Branch: `feat/panels-stage03-pr-a-wire-and-gate`

- `Panel_runner._build_strategy` — pass `~bar_reader:(Bar_reader.of_panels
  bar_panels)` to `Weinstein_strategy.make`. Today the wrapper inherits
  Tiered's `~bar_history`; this PR makes Panel mode actually read from
  panels.
- Replace `test_panel_loader_parity.ml`:
  - Drop "Tiered vs Panel" comparison (now structurally divergent — 5 vs
    3 trades on bull-2019h2 by design).
  - Add `Panel_round_trips_golden` test: run Panel mode on ≥2 scenarios
    (`smoke/tiered-loader-parity.sexp` + a second from
    `goldens-small/`), assert the full `round_trips` list bit-equality
    against a sexp golden checked in under `trading/test_data/`.
  - Round_trip equality covers: symbol, entry_date, entry_price,
    exit_date, exit_price, quantity, pnl, hold_days, exit_reason.
  - First run captures the golden; subsequent runs assert it.
- Tiered's own behavior continues to be tested by
  `test_tiered_loader_parity` (unchanged).
- Add a doc comment in `panel_runner.ml` referencing the timing
  divergence finding so the trade-count delta is not a surprise to
  reviewers.

Gate: new golden test passes; `dune runtest backtest` passes; existing
Tiered tests still pass. `dune build @fmt` clean.

### PR 3.2 — Delete Bar_history + Bar_reader.History (~600 LOC delete)

Branch: `feat/panels-stage03-pr-b-delete-bar-history`

- Delete `weinstein/strategy/lib/bar_history.{ml,mli}` (~85 LOC).
- Delete `weinstein/strategy/test/test_bar_history.ml`.
- `Bar_reader` collapses: remove `of_history` constructor +
  `accumulate` (was a no-op for Panels per pre-flag). Type becomes a
  thin newtype over `Bar_panels.t` or just an alias.
- Delete `Tiered_strategy_wrapper._run_friday_cycle` body (the seed
  step is now dead — wrapper still exists for trace bookkeeping until
  PR 3.3).
- Strategy no longer threads `~bar_history` — remove from
  `Weinstein_strategy.make` signature; callers updated.
- Test fixtures: delete Bar_history-based ones; keep Bar_panels
  fixtures (already present from Stage 2).
- Parity gate (3.1) must hold.

Gate: `dune runtest` passes (Tiered tests need updates — Friday cycle
no-ops but trace events change shape); golden parity holds.

### PR 3.3 — Delete Tiered runner + Bar_loader + Shadow_screener (~1000 LOC delete)

Branch: `feat/panels-stage03-pr-c-delete-tiered`

- Delete `backtest/lib/tiered_strategy_wrapper.{ml,mli}`,
  `backtest/lib/tiered_runner.{ml,mli}`.
- Delete `backtest/bar_loader/` directory entirely (`bar_loader`,
  `full_compute`, `summary_compute`, `shadow_screener` + 6 tests).
- Delete `Trace.Phase.Promote_metadata|Promote_summary|Promote_full|
  Demote` variants. Update remaining pattern-match sites (none in
  active runners after Tiered deletion; only test assertions).
- `runner.ml`: remove `_run_tiered_backtest`, `_tiered_input_of_deps`,
  `tier_op_to_phase` re-export. `Loader_strategy` enum drops `Tiered`
  variant.
- Delete tests: `test_runner_tiered_cycle`, `test_runner_tiered_skeleton`,
  `test_tiered_loader_parity`, `test_runner_tiered_metadata_tolerance`.
- Parity gate (3.1) must hold.

Gate: `dune runtest` passes; golden parity holds.

### PR 3.4 — Delete Legacy + finalize Panel-only (~250 LOC)

Branch: `feat/panels-stage03-pr-d-delete-legacy`

- Delete `_run_legacy` from `runner.ml` + Loader_strategy.Legacy
  variant. Loader_strategy enum either drops to single `Panel` variant
  or is deleted entirely (default to Panel in runner).
- Delete `backtest_runner` CLI flag for loader_strategy (or fix
  default).
- Drop `bars_for_volume_resistance` parameter from
  `Stock_analysis.analyze_with_callbacks` if Volume/Resistance
  reshape merged in parallel; otherwise leave with TODO.
- Pre-flag (PR-F) cumulative A-D fold semantics — verify int-then-float
  fold preserved in `Macro.callbacks_from_bars` (already done in PR-F;
  re-verify post-deletion).
- Pre-flag (PR-H QC) `Bar_reader.accumulate` removed in 3.2; verify
  no residual `_all_accumulated_symbols` plumbing.
- Parity gate (3.1) must hold.

Gate: `dune runtest` passes; golden parity holds. After PR 3.4 lands:
- `bull-crash-292x6y` RSS sweep validates ~10× memory drop projection.

## Parity gate (load-bearing per resume prompt)

Today's `test_panel_loader_parity` is "vacuous" (Panel callbacks
constructed but never queried). PR 3.1 strengthens to:
- Full `round_trips` list bit-equality (per-trade fields, all of them)
- ≥ 2 scenario fixtures (existing `tiered-loader-parity.sexp` + one
  from `goldens-small/`)
- If gate fails: STOP and surface; do not paper over with tolerance

## Carry-over pre-flags from Stage 2 QC

- (PR-D) `bars_for_volume_resistance` — drop in PR 3.4 if Volume +
  Resistance reshape lands in parallel; else defer to Stage 4
- (PR-F) Cumulative A-D fold semantics — Stage 4 panel kernel must
  match int-then-float fold in `Macro.callbacks_from_bars`
- (PR-H QC) `Bar_reader.accumulate` is dead weight on Panels path —
  removed in PR 3.2 with `_all_accumulated_symbols` plumbing

## Sequencing

PRs 3.1 → 3.2 → 3.3 → 3.4. Each merges to `main` independently after
QC structural + behavioral approval and CI green. Worktree isolation
per `.claude/rules/worktree-isolation.md`.

## Risks

- **R1 — Golden capture wrong.** PR 3.1 captures current Panel-mode
  output as goldens. If the upfront-load behavior is itself buggy,
  goldens encode the bug. Mitigation: review fixtures' round_trips for
  reasonableness; cross-check against discretionary expectations from
  `dev/notes/bull-crash-sweep-2026-04-25.md`.
- **R2 — Hidden Bar_history readers.** Audit was done at PR-H but PR
  3.2 must re-grep before the .mli is deleted. Any new reader added
  since PR-H must be ported.
- **R3 — Trace event coupling.** Removing Friday cycle changes trace
  shape; tests asserting phase counts (test_runner_tiered_*) get
  deleted in 3.3, but sibling tests reading traces may break.

## Total

~2150 LOC delete across 4 PRs over ~4 working days. Gate: golden
parity green at every step.
