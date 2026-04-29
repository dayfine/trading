# Status: optimal-strategy

## Last updated: 2026-04-29

## Status
MERGED

All planned phases shipped to `main`:

- **PR-1** (#652) — `Optimal_types` + `Stage_transition_scanner`.
- **PR-2** (#659) — `Outcome_scorer`.
- **PR-3** (#663) — `Optimal_portfolio_filler` + `Optimal_summary`.
- **PR-4** (#665) — `Optimal_strategy_report` markdown renderer.
- **PR-4 follow-up B** (#670) — fuller renderer fixture tests.
- **PR-4b** (#666) — `optimal_strategy.exe` binary scaffold.
- **PR-4c** (#672) — pipeline lib extraction (`Optimal_strategy_runner`
  + `Optimal_run_artefacts`); bin shrinks ~480 → ~35 LOC; PR-4 follow-up
  A smoke test ships here.
- **PR-5** (#677) — `release_perf_report` consumes per-scenario
  `optimal_summary.sexp`, renders Δ-to-optimal column + link to
  `optimal_strategy.md`.
- **Macro-trend write side** (#671) — per-Friday `macro_trend.sexp`
  artefact emitted by `Backtest.Macro_trend_writer`.
- **Macro-trend read side** (#676) — runner consumes the artefact;
  `Constrained` and `Relaxed_macro` variants now diverge on
  Bearish-macro Fridays.

## Goal

Quantify the gap between the strategy's actual performance and the
*theoretical optimum reachable under the same structural constraints*
(universe, sizing, stops). Replays each backtest with perfect-hindsight
candidate selection (still gated by Stage-1→2 breakout + Weinstein stop
discipline) and emits a counterfactual report showing actual vs ideal
P&L per scenario, surfacing per-Friday opportunity cost.

Sister track to `trade-audit`: the audit answers *why* a trade was
chosen and *what alternatives existed*; the counterfactual answers
*what was the best achievable across all alternatives* given the same
constraints.

Motivated by the same `goldens-sp500/sp500-2019-2023` baseline gap that
motivates trade-audit (+18.49% strategy vs ~+95% SPY); audit + counterfactual
together diagnose whether the gap is cascade-ranking error
(closeable) vs structural strategy limitation (requires deeper changes).

## Plan

`dev/plans/optimal-strategy-counterfactual-2026-04-28.md` — full design:
goal definition (constrained vs relaxed-macro variants), 4-phase
algorithm (scanner → outcome scorer → greedy filler → report renderer),
4–5 PR phasing, ~1,600 LOC total.

## Interface stable
NO

## Open work

**PR-4 — `Optimal_strategy_report` + binary** — partial landing in
flight. Per plan §Phase D + §PR-4:

- `trading/trading/backtest/optimal/lib/optimal_strategy_report.{ml,mli}`
  — pure markdown renderer. Inputs: actual round-trips + summary +
  optimal round-trips + summary (constrained + relaxed). Output:
  markdown string with headline comparison table, per-Friday divergence
  table, "trades the actual missed", "trades the actual took",
  implications block. Disclaimer in header.
- `trading/trading/backtest/optimal/bin/optimal_strategy.ml` — thin
  binary: reads `output_dir/`'s artefacts (`trades.csv`,
  `summary.sexp`, panel), invokes
  `Stage_transition_scanner` →
  `Outcome_scorer` →
  `Optimal_portfolio_filler` (×2 variants) →
  `Optimal_summary` (×2) →
  `Optimal_strategy_report.render`. Writes
  `<output_dir>/optimal_strategy.md`.
- `trading/trading/backtest/optimal/bin/dune` — register exe.
- `trading/trading/backtest/optimal/test/test_optimal_strategy_report.ml`
  — fixture with seeded actual + counterfactual round-trips; assert
  rendered markdown contains expected divergence rows, outlier callouts,
  and the right implications-block narrative for the seeded ratio.

LOC estimate: 400.

The filler + summary types from PR-3 are already stable, so PR-4 is
ready to start once PR-3 lands.

## Phasing (per plan)

- [x] **PR-1**: `Optimal_types` data model + `Stage_transition_scanner`
      — PR #652 (merged), branch `feat/optimal-strategy-pr1`.
      Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`.
- [x] **PR-2**: `Outcome_scorer` — realized-outcome scorer per candidate
      (Stage3-transition vs stop-hit forward walk) — PR #659 (merged),
      branch `feat/optimal-strategy-pr2`. ~300 LOC.
- [x] **PR-3**: `Optimal_portfolio_filler` — greedy sizing-constrained
      fill + `Optimal_summary` aggregator — branch
      `feat/optimal-strategy-pr3`. ~1,073 LOC including tests
      (interface ~145, implementation ~315, tests ~575). 15 OUnit2
      cases (10 filler + 5 summary), all passing.
- [x] **PR-4**: `Optimal_strategy_report` markdown renderer + smoke
      tests on `feat/optimal-strategy-pr4` — PR #665 (merged 2026-04-29).
      Renderer ~538 LOC
      lib (already over the original 400-LOC plan estimate), 8 OUnit2
      smoke tests on the renderer (section presence, headline-3-variants,
      missed-trade-with-rejection-reason, three implications branches,
      determinism, trailing newline). 45/45 pass across the optimal track.
      The binary + deeper fixture tests are deferred to PR-4b — see
      `dev/notes/optimal-strategy-pr4-followups-2026-04-28.md`.
- [x] **PR-4b**: `optimal_strategy.exe` binary (panel loading + pipeline
      orchestration) — PR #666 (merged 2026-04-29). Bin scaffold +
      `bin/dune`; panel-walking smoke test deferred to PR-4c lib
      extraction. Macro-trend hardcoded to `Neutral` until the read-side
      wiring of #671's artefact lands.
- [x] **PR-4 follow-up B**: fuller per-Friday divergence + missed-trade
      ordering fixture tests on `feat/optimal-strategy-pr4-followup-b`.
      Three new cases in `test_optimal_strategy_report.ml` pin specific
      symbols / sizes / R-multiples in the divergence section, the
      missed-trades descending-by-P&L ordering, and the no-divergence
      sentinel. 45 → 48 tests pass. PR #670 (merged 2026-04-29).
- [x] **PR-4c**: lib extraction (merged 2026-04-29 as #672). Pipeline
      orchestration code moved from `bin/optimal_strategy.ml` into
      `lib/optimal_strategy_runner.ml` \+ `lib/optimal_run_artefacts.ml`;
      bin shrinks from ~480 LOC to ~35 LOC. Landed the deferred
      synthetic-panel smoke test (2 new OUnit2 cases) which is now
      possible because the entry point is a lib function. Branch
      `feat/optimal-strategy-runner-lib` / PR #672.
      Verify: `dev/lib/run-in-env.sh dune runtest
      trading/backtest/optimal/` (47/47 pass: 45 prior + 2 new smoke
      tests). Unblocks the macro-persistence read-side wiring (a clean
      lib edit instead of a 480-line bin edit).
- [x] **PR-5**: wire `optimal_strategy.exe` artefacts into
      `release_perf_report`. Runner now emits structured
      `<output_dir>/optimal_summary.sexp` via the new
      `Optimal_summary_artefact` module; release report renders an
      "Optimal-strategy delta" section (per-scenario sub-table with
      Actual / Constrained / Δ / Relaxed rows + a markdown link to
      `<scenario>/optimal_strategy.md`) for paired scenarios where at
      least one side has the artefact. Verify:
      `dev/lib/run-in-env.sh dune exec trading/backtest/test/test_release_perf_report.exe`
      (22/22) and
      `dev/lib/run-in-env.sh dune exec trading/backtest/optimal/test/test_optimal_strategy_runner.exe`
      (3/3). Branch `feat/optimal-strategy-pr5-release-report` /
      TBD.

### Macro-trend persistence (write/read split)

- [x] **Write side**: per-Friday `macro_trend.sexp` artefact emitted by
      `Backtest.Result_writer` on every backtest run. Sourced from
      `Trade_audit.cascade_summary.{date,macro_trend}` (already populated
      by the strategy's `Macro.analyze_with_callbacks` call inside
      `_run_screen` — no plumbing changes needed). Module:
      `trading/trading/backtest/lib/macro_trend_writer.{ml,mli}`. Verify:
      `dev/lib/run-in-env.sh dune exec trading/backtest/test/test_macro_trend_writer.exe`.
      Branch / PR: `feat/scenario-runner-macro-persistence` / TBD.
- [x] **Read side**: per-Friday lookup wired in. New
      `Optimal_strategy_runner.load_macro_trend ~output_dir`
      (`trading/trading/backtest/optimal/lib/optimal_strategy_runner.{ml,mli}`)
      reads `<output_dir>/macro_trend.sexp` via
      `Backtest.Macro_trend_writer.t_of_sexp` into a
      `(Date.t, market_trend) Hashtbl.t` and plumbs it through
      `_world` → `_scan_and_score` → `_scan_all_fridays`. The
      `_scan_all_fridays` callsite now resolves each Friday's macro
      via `Hashtbl.find … |> Option.value ~default:Neutral`,
      replacing the prior hardcoded `Weinstein_types.Neutral`. Missing
      file (legacy runs that predate #671) ⇒ empty table + stderr
      warning ⇒ `Neutral` fallback at every lookup, so the pipeline
      still completes for old artefacts. With the file present,
      `Bearish` Fridays now flip `passes_macro = false` for that
      week's candidates, so `Constrained` filters them while
      `Relaxed_macro` admits them — the variants diverge on
      macro-driven outcomes. Tests added: 3 new OUnit2 cases in
      `test_optimal_strategy_runner.ml` (5 → was 2 with PR-4c) —
      direct loader test (3-Friday Bullish/Neutral/Bearish round-trip),
      missing-file fallback, and end-to-end runner consumption with a
      staged `macro_trend.sexp`. The honest divergence test (variants
      produce different round-trip counts on a Bearish week with an
      actual breakout) is a follow-up that needs hand-crafted Stage-1→2
      OHLCV bars in the synthetic fixture; the existing flat-price
      fixture produces zero candidates either way. Verify:
      `dev/lib/run-in-env.sh dune build` +
      `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`
      (53/53 pass: 50 prior + 3 new). Branch / PR:
      `feat/optimal-strategy-macro-read` / PR TBD.

## Ownership

`feat-backtest` agent — sibling of backtest-infra, backtest-perf,
trade-audit. Consumes existing screener cascade
(`Stock_analysis.is_breakout_candidate`, `Screener.scored_candidate`),
stop machinery (`Weinstein_stops`), and panel infrastructure
(`Bar_panel`). Does not modify strategy logic — counterfactual is a
pure-functional analysis layer over backtest outputs.

## Branch

Implementation branches per phase:

- `feat/optimal-strategy-pr1` — PR #652 (merged).
- `feat/optimal-strategy-pr2` — PR #659 (merged).
- `feat/optimal-strategy-pr3` — current PR (READY_FOR_REVIEW).
- `feat/optimal-strategy-pr4` (next).

Plan branch: `docs/optimal-strategy-counterfactual-plan` (merged via
PR #650, 2026-04-28).

## Blocked on

None. The pure-functional stop walker (plan §Risks item 4) was resolved
in PR-2 by seeding `Weinstein_stops.update` directly with the
candidate's `suggested_stop`. PR-3 does not touch stops at all — it
consumes scorer output as opaque exit fields.

## Authority docs

- User quote (2026-04-28) captured in plan §Context
- Sister plan: `dev/plans/trade-audit-2026-04-28.md`
- Perf framework: `dev/plans/perf-scenario-catalog-2026-04-25.md`
- Stage classifier: `trading/analysis/weinstein/stage/lib/stage.{ml,mli}`
- Screener cascade: `trading/analysis/weinstein/screener/lib/screener.{ml,mli}`
- Stops: `trading/trading/weinstein/portfolio_risk/`
- Book ref: `docs/design/weinstein-book-reference.md`

## Completed

- **PR-1** (2026-04-28): `Optimal_types` data model +
  `Stage_transition_scanner`.
  - Files added:
    - `trading/trading/backtest/optimal/lib/dune`
    - `trading/trading/backtest/optimal/lib/optimal_types.{ml,mli}`
    - `trading/trading/backtest/optimal/lib/stage_transition_scanner.{ml,mli}`
    - `trading/trading/backtest/optimal/test/dune`
    - `trading/trading/backtest/optimal/test/test_stage_transition_scanner.ml`
  - Coverage: 13 OUnit2 cases — sexp round-trip on each record type;
    scanner emits one per breakout in arrival order; non-breakouts
    dropped; `passes_macro` tagging across Bullish/Neutral/Bearish;
    missing-sector fallback to "Unknown"; entry/stop/risk match screener
    formulas; multi-week scan_panel concatenation; empty-input edge
    cases.
  - Verify:
    - `dev/lib/run-in-env.sh dune build`
    - `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`
    - `dev/lib/run-in-env.sh dune build @fmt`
  - Branch / PR: `feat/optimal-strategy-pr1` / PR #652 (merged).

- **PR-2** (2026-04-28): `Outcome_scorer` realised-outcome walker.
  - Files added:
    - `trading/trading/backtest/optimal/lib/outcome_scorer.{ml,mli}`
    - `trading/trading/backtest/optimal/test/test_outcome_scorer.ml`
  - Coverage: 9 OUnit2 cases — one fixture per `exit_trigger` variant
    (`Stage3_transition`, `Stop_hit`, `End_of_run`); R-multiple
    arithmetic pin; empty-forward / immediate stop / invalid-candidate
    edges; Stage-3 streak reset on Stage-2 break; sensitivity at
    `stage3_confirm_weeks = 1`.
  - Verify: same as PR-1.
  - Branch / PR: `feat/optimal-strategy-pr2` / PR #659 (merged).

- **PR-3** (2026-04-28): `Optimal_portfolio_filler` greedy fill +
  `Optimal_summary` aggregator.
  - Files added:
    - `trading/trading/backtest/optimal/lib/optimal_portfolio_filler.{ml,mli}`
    - `trading/trading/backtest/optimal/lib/optimal_summary.{ml,mli}`
    - `trading/trading/backtest/optimal/test/test_optimal_portfolio_filler.ml`
    - `trading/trading/backtest/optimal/test/test_optimal_summary.ml`
  - `trading/trading/backtest/optimal/test/dune` updated to register
    the two new test executables.
  - Coverage:
    - 10 filler cases — empty input, Constrained-variant macro filter,
      Relaxed_macro admits both, R-descending tie ordering, concurrent
      cap forces lower-rank skip, sector cap forces skip, cash
      exhaustion forces skip, skip-already-held, end-of-run close-out,
      cash recycles after exit funds a later entry.
    - 5 summary cases — empty input -> zero summary with
      `profit_factor = +infinity`, seeded 2-winners + 1-loser pin
      (every metric value pinned), drawdown over multiple Fridays,
      same-Friday batching of equity steps, no-losers infinite profit
      factor.
  - Heuristic A only (earliest-Friday + R-descending). Heuristics B
    (knapsack) and C (Monte-Carlo) are PR-5 follow-ups per plan
    §Phase C.
  - Verify:
    - `dev/lib/run-in-env.sh dune build`
    - `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`
    - `dev/lib/run-in-env.sh dune build @fmt`
  - Branch / PR: `feat/optimal-strategy-pr3` / PR #TBD.

- **PR-4b** (2026-04-29, MERGED): `optimal_strategy.exe` binary —
  thin orchestration wrapper that wires the existing pure-functional
  optimal-lib pipeline (scanner → scorer → filler ×2 → summary ×2) to
  artefacts on disk and emits `<output_dir>/optimal_strategy.md`.
  - Files added:
    - `trading/trading/backtest/optimal/bin/dune`
    - `trading/trading/backtest/optimal/bin/optimal_strategy.ml`
  - Coverage: existing 45/45 optimal-track tests still pass; no new
    unit tests in this commit. Smoke test (synthetic-panel fixture
    invoking `main`) deferred to PR-4c.
  - Macro-trend simplification: bin uses fixed `Neutral` for every
    Friday because run artefacts don't persist per-Friday macro state.
    `Constrained` and `Relaxed_macro` therefore tag every candidate
    identically until macro persistence lands; the headline
    cascade-ranking comparison is unaffected. Documented in the bin's
    docstring. Read-side wiring of #671's `macro_trend.sexp` artefact
    is a small follow-up.
  - Cascade rejections sourced from `trade_audit.sexp`'s
    `alternatives_considered` when present; missing-audit case passes
    `[]` and the renderer drops rejection annotations from missed-trade
    rows.
  - Verify:
    - `dev/lib/run-in-env.sh dune build`
    - `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`
    - `dev/lib/run-in-env.sh dune build @fmt`
  - Branch / PR: `feat/optimal-strategy-pr4b` / PR #666.

- **PR-4 follow-up B** (2026-04-29, MERGED): fuller renderer fixture tests.
  - Files modified:
    - `trading/trading/backtest/optimal/test/test_optimal_strategy_report.ml`
      (3 new OUnit2 cases, ~205 LOC of additions; no production code
      touched).
  - Coverage:
    - `test_divergence_pins_specific_cells` — 2 actual + 4 counterfactual
      round-trips across 2 Fridays. Pins `### YYYY-MM-DD` subheaders,
      actual `SYM (N sh)` cells, and optimal `SYM (N sh, R=±X.XX)` cells
      with R-multiples to two decimals (per `_fmt_actual_pick` and
      `_fmt_optimal_pick` in the renderer).
    - `test_missed_trades_ordered_by_pnl_descending` — 3 missed-trade
      candidates with P&L 300 / 1000 / 50 (alphabetical order
      `AAA`/`MSML`/`ZBIG` deliberately disagrees with P&L order). Test
      restricts the substring search to the missed-trades section so
      the divergence section's symbol mentions don't pollute, then
      asserts position(`ZBIG`) < position(`AAA`) < position(`MSML`)
      via `lt (module Int_ord)`. Pins the descending-by-`pnl_dollars`
      ordering documented in the renderer's `.mli`.
    - `test_empty_divergence_renders_sentinel` — identical actual /
      counterfactual symbol sets => the divergence section emits the
      single sentinel line `_No Fridays where actual and constrained-
      counterfactual picks differed._` and no per-Friday detail rows
      (`### YYYY-MM-DD` substring absent).
  - Test count: 45 → 48 across the optimal track.
  - Verify:
    - `dev/lib/run-in-env.sh dune build`
    - `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`
    - `dev/lib/run-in-env.sh dune build @fmt`
  - Branch / PR: `feat/optimal-strategy-pr4-followup-b` / PR #670.

- **PR-4c** (2026-04-29, in flight): pipeline orchestration extracted
  from the bin into reusable lib modules, plus the deferred
  synthetic-panel smoke test (PR-4 follow-up A).
  - Rationale: the bin sat at ~480 LOC and contained substantively all
    of the pipeline (sexp shape mirrors, CSV trade-row parser,
    cascade-rejection harvest, panel construction, Friday math, scan
    + score, four pipeline phases). Extracting unblocks the deferred
    smoke test (a binary entry can't be unit-tested without a process
    round-trip) and turns the upcoming macro-persistence read-side
    wiring (Read side TODO above) into a clean lib edit.
  - Files added:
    - `trading/trading/backtest/optimal/lib/optimal_run_artefacts.{ml,mli}`
      — sexp shapes (`actual.sexp` + `summary.sexp`) + trades.csv
      parser + trade-audit cascade-rejection harvest, returning a
      bundled `actual_run_inputs` record. Tolerates missing optional
      artefacts; logs malformed rows / parse failures to stderr and
      drops them.
    - `trading/trading/backtest/optimal/lib/optimal_strategy_runner.{ml,mli}`
      — pipeline orchestration: builds the bar-panel world, scans +
      scores per Friday, fills + summarises both variants, renders the
      report. Single entry point: `Optimal_strategy_runner.run
      ~output_dir : unit`.
    - `trading/trading/backtest/optimal/test/test_optimal_strategy_runner.ml`
      — 2 OUnit2 smoke tests against a synthetic-panel fixture
      (one-symbol OHLCV CSV + sectors.csv staged in a tmpdir,
      `TRADING_DATA_DIR` overriden via `Core_unix.putenv` for the
      duration of the call). Asserts the runner writes
      `<output_dir>/optimal_strategy.md` with the disclaimer + scenario
      name; second case omits `trade_audit.sexp` and asserts the
      missed-trades section emits no `(reason: ...)` annotations.
  - Files modified:
    - `trading/trading/backtest/optimal/bin/optimal_strategy.ml`
      — shrinks from ~480 LOC to 35 LOC. Now a thin CLI wrapper that
      parses `--output-dir` and dispatches to
      `Backtest_optimal.Optimal_strategy_runner.run`.
    - `trading/trading/backtest/optimal/bin/dune` — drops 11 of its
      13 library deps (everything moved to the lib); keeps only `core`
      \+ `backtest_optimal`.
    - `trading/trading/backtest/optimal/lib/dune` — pulls in the deps
      that came from the bin (`core_unix.sys_unix`, `trading.data_panel`,
      `weinstein.data_source`, `backtest`).
    - `trading/trading/backtest/optimal/test/dune` — registers the new
      test executable + adds `core_unix`, `core_unix.sys_unix`, `fpath`,
      `csv` deps for the fixture-staging helpers.
  - Two-module split rationale: the runner is 326 LOC standalone; with
    the artefact loaders inlined it would be 460 LOC and cross the
    typical lib-module size cliff. Splitting on the load-vs-orchestrate
    seam keeps each module under 350 LOC and lets the artefact loader
    be tested independently if needed later.
  - Macro-trend hardcode preserved (`Weinstein_types.Neutral` at the
    `_scan_all_fridays` callsite) with an inline `(* TODO follow-up:
    read macro_trend.sexp once #671 merges *)` comment marking the
    exact fix location for the read-side wiring follow-up.
  - Test count: 45 → 47 across the optimal track (5 + 10 + 8 + 2 +
    9 + 13 — the +2 is the new runner smoke tests).
  - Verify:
    - `dev/lib/run-in-env.sh dune build`
    - `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`
    - `dev/lib/run-in-env.sh dune build @fmt`
  - Branch / PR: `feat/optimal-strategy-runner-lib` / PR #672.

- **PR-5** (2026-04-29): wire optimal-strategy counterfactual delta + link
  into `release_perf_report`. Runner now emits a structured
  `<output_dir>/optimal_summary.sexp` artefact alongside the existing
  markdown report; release-report consumes it to render an
  "Optimal-strategy delta" section per paired scenario with the
  constrained / relaxed-macro variants, Δ_constrained / Δ_relaxed (in
  percentage points), and a markdown link to the per-scenario
  `optimal_strategy.md`. Missing artefacts on either side render as
  `—` and the link cell is empty; the section as a whole is omitted
  if both sides are missing.
  - Files added:
    - `trading/trading/backtest/optimal/lib/optimal_summary_artefact.{ml,mli}`
      — small two-field record (`constrained` / `relaxed_macro`) carrying
      the runner's `Optimal_summary.t` outputs, with a `write` helper that
      sexp-saves to `<output_dir>/optimal_summary.sexp`. Pulled out of the
      runner so the runner's body stays close to the 300-line norm and the
      on-disk shape has its own home.
  - Files modified:
    - `trading/trading/backtest/optimal/lib/optimal_strategy_runner.{ml,mli}`
      — `_emit_report` calls `Optimal_summary_artefact.write` after the
      markdown emit; mli's "I/O surface" lists the new artefact.
    - `trading/trading/backtest/optimal/test/test_optimal_strategy_runner.ml`
      — new `test_run_emits_optimal_summary_sexp` smoke (3 → +1 = 4
      cases overall when the suite is run; the existing 2 cases still
      pin the markdown contract).
    - `trading/trading/backtest/release_report/release_report.{ml,mli}`
      — adds `optimal_summary` + `optimal_summary_pair` types,
      a `_try_load_optimal_summary` loader that requires both
      `optimal_summary.sexp` and `optimal_strategy.md` (avoids 404
      links), and `_optimal_strategy_section` renderer — sub-table per
      paired scenario with the link cell + 5 metric rows.
    - `trading/trading/backtest/test/test_release_perf_report.ml` — 6
      new OUnit2 cases (16 → 22): omit-when-both-none, full pin with
      hand-computed Δ, one-sided rendering with em-dash placeholders,
      loader round-trip, both-files-missing → None, sexp-only-missing-md
      → None.
  - Decision: structured sexp over markdown parsing. Reasons: (a) the
    renderer evolves separately so markdown sections may shift, (b) the
    `Optimal_summary.t` already derives sexp so the producer side is a
    one-line emit, (c) `release_report` mirrors the shape locally with
    `[@@sexp.allow_extra_fields]` and avoids a heavy dep on
    `backtest_optimal`.
  - Verify:
    - `dev/lib/run-in-env.sh dune build`
    - `dev/lib/run-in-env.sh dune exec trading/backtest/test/test_release_perf_report.exe` (22/22 pass)
    - `dev/lib/run-in-env.sh dune exec trading/backtest/optimal/test/test_optimal_strategy_runner.exe` (3/3 pass)
    - `dev/lib/run-in-env.sh dune build @fmt`
  - Branch / PR: `feat/optimal-strategy-pr5-release-report` / TBD.
