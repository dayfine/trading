# Status: Backtest Infrastructure

## Last updated: 2026-06-14

## Status
IN_PROGRESS

<!-- 2026-06-14 orchestrator reconcile: header was stale (MERGED / 2026-05-01)
     while this-week measurement-correctness work merged under this track
     (#1558 Fold_health wiring, #1561/#1566 warmup-suppression flip). The
     index already lists this track IN_PROGRESS; header now matches. Forward
     work (P2 matrix on the composition-policy universe) is data-gated — see
     §Next Steps and the daily-summary escalations. -->

Step 1 (#399) + Step 2 (#419) landed long ago. Step 3 continued on
the backtest-scale track. The perf-sweep harness extension (#547)
landed 2026-04-25. Continuous perf monitoring + benchmark-suite work
moved to its own track at `dev/status/backtest-perf.md`. The 12-step
incremental-indicators refactor (the follow-on architecture for
Tier 3) tracked separately at `dev/status/incremental-indicators.md`.

## 2026-07-23 — deep-results headline block (rendered from pinned records)

- [x] **`readme_toplines` deep-headline block + `Deep_headline` module** —
  extends the README regenerator with a SECOND marker-delimited block
  (`<!-- deep-headline:start/end -->`) that renders the heavy multi-decade
  broad-universe results-of-record. Per dispatcher decision, the tool does
  **NOT** recompute these (top-3000 uses an out-of-repo warehouse CI can't
  reach); it renders from a checked-in pinned sexp,
  `dev/backtest/deep_headline_records.sexp` (machine-readable mirror of
  `DEEP_RESULTS.md`). New promoted-bundle 28y record is now the README
  headline: **+8,689% / DD 30.3% / 1,170 trades / 38.4% win / 2000→2026-06-26**,
  scenario `staging-leverf-28y/top3000-2000-2026-rcb-f000.sexp` @ commit
  `6a2d9b426` (PR #2047); Run-D +7,914% row kept as superseded; SPY-TR +706%
  comparator. Standing MTM / realized-vs-MTM / liquidity caveat rendered inline.
  - **Where:** `Deep_headline.{ml,mli}` (records type + sexp load + renderer),
    `Readme_block` refactored to expose generic `render_between`/`upsert_between`
    (the light-block `render`/`upsert` now specialise them — behaviour of the
    light block is unchanged, existing tests untouched), bin renders + upserts
    both blocks (deep above light), all under
    `trading/trading/backtest/readme_toplines/`. Records file + DEEP_RESULTS row
    updated.
  - **Missing-file behaviour:** absent records sexp → deep block skipped with a
    stderr warning (README's existing block untouched), never a crash; a present
    but malformed sexp raises (checked-in data defect). Unit-tested.
  - **Verify:** `dune runtest trading/backtest/readme_toplines/` (8 new
    `test_deep_headline` cases: render/format, marker upsert isolation,
    optional-field dash, load round-trip, missing-file→None, malformed→raise);
    regenerate with `dune exec backtest/readme_toplines/bin/readme_toplines.exe
    -- --readme README.md`.

## 2026-07-12 — trades.csv export-join fix (C2)

- [x] **Key `exit_trigger` + `stop_trigger_kind` by position_id** — the
  trades.csv export sourced `exit_trigger` (and `entry_stop` / `exit_stop`)
  from a symbol-keyed FIFO pop of `stop_info`s while `stop_trigger_kind`
  (via `Trade_context`) resolved position-keyed through the audit record.
  On re-traded symbols the two joins mis-aligned, producing blank and
  contradictory trigger rows (record run: 129 validator-V5 violations; e.g.
  WSM 2017-10-14 `exit_trigger=laggard_rotation` vs `stop_trigger_kind=gap_down`).
  Fix routes both columns through the single position-keyed join
  `Trade_context.stop_info_for_trade`, and appends a trailing **`position_id`**
  column to trades.csv (canonical audit id; join key for the validator's
  audit lookup). No strategy-behaviour change — backtest returns/positions are
  bit-identical; only trigger columns change on re-traded symbols. `position_id`
  is appended last so positional readers (validator fixed indices
  `exit_trigger`=12, `stop_trigger_kind`=16; hold-period/extension analyzers)
  stay valid. Lives at `trading/trading/backtest/lib/{trade_context,result_writer}.ml`.
  **Verify:** `dune runtest trading/backtest/test/` (test_trade_context +
  test_result_writer: new re-traded-symbol per-position join tests) and
  `dune runtest trading/backtest/validation/` (new V5 re-traded-consistent
  fixture). PR: `feat/trades-export-join-fix` — MERGED #1942 (3-gate auto-merge, 2026-07-12 run-2).

## 2026-07-09 — `audit_bars` warehouse corrupt-bar scanner

- [x] **`audit_bars` exe + `audit_bars_detector` lib** — scans a snapshot
  warehouse for MSZ-class corrupt bars (one-day close spike that reverts the
  next day, the ELCO/MSZ delisted-micro-cap artifact class) so a deep
  re-baseline can be data-audited before it is trusted. Implements
  recommendation #2 of `dev/notes/deep-remeasure-364-2026-07-09.md` §"MaxDD
  59.4% is an artifact" (the MSZ 2014 1.90→25.36→1.93 spike-reverts that
  produced a phantom +$3.3M NAV spike and a fake 59.4% MaxDD). Lives at
  `trading/trading/backtest/snapshot_warehouse/audit_bars/{lib,bin,test}/`,
  alongside `dump_snap`. Pure detector (`Audit_bars_detector.detect`) is
  unit-tested (OUnit2 + Matchers): catches the MSZ shape, ignores a
  sustained/non-reverting move, ignores high-priced names above the ceiling,
  handles window-edge + last-bar cases. All four thresholds (`--spike-mult`
  `--median-window` `--revert-frac` `--price-ceiling`) are CLI flags, defaults
  5.0 / 5 / 0.5 / 5.0. **Verify:** `dune build` +
  `dune runtest trading/backtest/snapshot_warehouse/audit_bars/`; acceptance run
  `dune exec .../audit_bars/bin/audit_bars.exe -- /tmp/snap_top3000_1998_2026`
  finds the known MSZ 2014 bars (2014-08-15, 2014-11-11, 2014-12-26, 2014-12-31,
  2015-01-06) — 3797 hits across 81 symbols of 2999 scanned.

## 2026-06-16 — README top-line results module + bin

- [x] **`readme_toplines` lib + bin** — computes four headline numbers over one
  pinned full-history period and writes them into a comment-delimited block in
  the repo-root `README.md`, idempotently regenerable. Lives at
  `trading/trading/backtest/readme_toplines/{lib,bin,test}/`. Pure pieces
  (`Coverage` period-intersection + return math; `Readme_block` marker upsert)
  are unit-tested; the two backtest figures run `Backtest.Runner.run_backtest`
  (CSV mode) on the SPY-only and sector-rotation reference strategies.
  - **Pinned period** (from actual CSV coverage): **1998-12-22 → 2026-06-12**,
    bound by the nine original (Dec-1998) SPDR sector ETFs; XLRE (2015) / XLC
    (2018) are excluded from the period-defining set but still join the sector
    universe mid-run via `Daily_price.active_through`.
  - **Numbers (this data snapshot):** SPY buy-and-hold +888.9% (+8.7%/yr,
    div-adj); BRK-B +1132.4% (+9.6%/yr, div-adj); SPY-only Weinstein +408.0%
    (+6.1%/yr); Sector-ETF Weinstein (k=3, 30wk MA) +528.9% (+6.9%/yr). Both
    Weinstein figures under-return buy-and-hold over this bull-heavy window —
    consistent with the let-winners-run / dodge-drawdown tradeoff
    (`project_edge_is_the_fat_tail`). These are reporting artefacts, not a
    strategy change; no `Weinstein_strategy` edits, no default flips.
  - **Verify / regenerate:** `dune exec
    backtest/readme_toplines/bin/readme_toplines.exe -- --readme README.md`
    (dune root `trading/trading`, run in the dev container). `--check` is a
    CI-friendly drift check (non-zero exit when the block is stale).
  - Plan: `dev/plans/readme-toplines-2026-06-16.md`.

## 2026-06-13 — `suppress_warmup_trading` default flipped false→true (measurement-correctness BUGFIX)

- [x] **Flipped the default `false→true` per USER DIRECTIVE (2026-06-13:
  "measured window = window only").** This is a **measurement-semantics
  correction, not an alpha-mechanism promotion** — so `experiment-flag-discipline`
  R1/R3 (the ledger-ACCEPT gate that governs flipping *alpha* defaults) do
  **not** apply. The directive: a backtest's measured window must contain only
  that window's activity — "a 210-day backtest has trades for 210 days, not 420."
  Warmup exists only to form indicators; trading during it contaminates the
  measured return with pre-window activity / inherited positions. Default-true
  makes the number honest; default-false (legacy "running start") is kept as a
  config escape hatch + searchable axis for reproducing pre-flip baselines and
  measurement experiments.
  - **Note vs the merged experiment:** `dev/experiments/warmup-comparison-2026-06-12/ANALYSIS.md`
    concluded "DO NOT FLIP" on a *performance* axis (suppress lowers WF-CV
    Sharpe/return/Calmar — warmup trading is a net-beneficial bull "running
    start"). The user has **explicitly reframed** the flag as a *correctness*
    invariant, where that very "running start" gain is the contamination to
    remove (it belongs to the pre-window period). The two are different
    epistemic objects; the directive governs.
  - **Lives at:** `weinstein_strategy_config.{ml,mli}` (type field
    `[@sexp.default true]` + `default_config` initializer `true`),
    `weinstein_strategy.mli` (mirror field + docstring). Gate code (`Warmup_trade_gate`,
    `panel_runner.ml`) unchanged — only the default value moved.
  - **Live path unaffected (verified):** the gate is wired only in
    `panel_runner.ml` (the backtest path), keyed off the measurement `start_date`,
    and only drops `CreateEntering` transitions dated *strictly before* it. In
    live/forward mode `start_date` = "now" and the strategy never emits entries
    dated in the past, so the gate never fires — default-true is a no-op there.
  - **Re-pin scale: ZERO goldens re-pinned.** Full `dune build && dune runtest`
    passes **exit 0** with the flip. This matches the experiment's
    estimand finding: warmup trading only bites at the **walk-forward fold**
    level (`warmup_start = fold_start − 210d` sits mid-data with warm
    indicators); for a **standalone scenario/snapshot golden**, `warmup_start`
    IS the simulator's first day, so it carries **zero** warmup-built positions
    into measurement → off == on, bit-identical for every golden in the suite.
    (The two `trade #0 differs` log lines are the `Test_determinism` start-shift
    test asserting *expected* divergence — `Ran: 6 tests ... OK`.)
  - **Test:** `test_weinstein_strategy.ml` +1
    (`default_config suppresses warmup trading` pins `default_config.suppress_warmup_trading = true`).
    The existing `warmup_gate` unit tests + the `test_variant_matrix` axis test
    stay green (gate logic unchanged).
  - **Verify:** `dune build && dune runtest` (exit 0, zero golden diffs).
  - **Branch:** `feat/warmup-trading-default-flip`.

## 2026-06-12 — `suppress_warmup_trading` flag (warmup-leak root-fix surface)

- [x] **Default-off warmup-trading gate (P0, PR #1549 A2 follow-up).** Added a
  no-op-default `suppress_warmup_trading : bool [@sexp.default false]` config
  field on `Weinstein_strategy.config` plus a pure runner-side gate
  (`Warmup_trade_gate`) that drops the strategy's `CreateEntering` transitions
  (long and short) dated before the measurement `start_date`. The simulator
  runs from `warmup_start = start_date - warmup_days`, so absent the flag the
  strategy trades during the 210-day warmup window and every backtest inherits
  a warmup-built portfolio at measurement start (the #1549 A2 root cause: the
  2009-06-26 fold's warmup spanned the GFC bottom → portfolio depleted to ~35%
  before measurement opened).
  - **Lives at:** `trading/trading/backtest/warmup_gate/lib/warmup_trade_gate.{ml,mli}`
    (micro-lib `warmup_trade_gate`), wired in `panel_runner.ml`
    `_make_simulator` after `Strategy_wrapper.wrap`.
  - **R1 default-off:** `suppress = false` short-circuits both
    `filter_transitions` and `wrap_strategy` to the identity, so every
    golden/snapshot/scenario decodes (via `[@sexp.default false]`) and replays
    bit-equal. Full `dune build && dune runtest` exits 0 with the flag absent.
    `Backtest.Fold_health` signatures fire exactly as before (terminal facts
    unchanged with the flag off).
  - **R2 axis-able (verified):** top-level bool flag, so `Variant_matrix`
    resolves it by sexp name through `Overlay_validator` with no
    overlay-validator change (same mechanism as `neutral_blocks_longs`). Axis
    test added to `test_variant_matrix.ml`
    (`suppress_warmup_trading flag axis expands`).
  - **R3:** not wired into any default config or preset (stays default-off).
  - **Scope:** only new-position entries are suppressed; exits / partial exits
    / risk-param updates / fills are never dropped (warmup-window exit/stop
    handling is never broken).
  - **Verify:** `dune runtest trading/backtest/warmup_gate/` (7 unit tests:
    no-op at false, drop-warmup-entry, inclusive boundary, short-side, never
    drop non-entries, `wrap_strategy` end-to-end both flag states).
  - **Plan:** `dev/plans/warmup-trading-flag-2026-06-12.md`. Branch
    `feat/warmup-trading-flag`.
  - **Next (out of scope here):** the comparison run quantifying how every
    baseline shifts with the flag ON, then walk-forward CV + confirmation grid
    before any promotion (P0 analysis step, `experiment-flag-discipline` R3).

## 2026-06-12 — Fold_health divergence runner wiring (#1557 item 1)

- [x] **`Fold_health.check_divergence` wired into the runner path.** PR #1556
  landed the pure `Stuck_held_positions` finding + `check_divergence`
  (config-thresholded `max_stuck_held_positions`, default 0) but descoped the
  runner wiring — nothing fed it the two position counts. This wires it as a
  tripwire so the finding can fire in real runs (the #1553 THM zombie: portfolio
  held it, strategy state terminally `Exiting`, stop never re-evaluated).
  - **Seam (additive, no core-module edit):** `run_result` gains
    `n_stop_eligible_positions : int` — the count of strategy positions in the
    `Holding` state (still under stop evaluation) at end of run, populated in
    `Simulator._build_run_result` via `_count_stop_eligible t.positions`.
    Threaded through `Runner.result.n_stop_eligible_positions` in
    `_assemble_result`. `Fold_health_runner.open_position_count` counts
    `final_portfolio.positions` (closed positions already dropped, matching the
    `open_positions.csv` per-row semantics); `Fold_health_runner.divergence_findings`
    derives both counts and calls `check_divergence`. `scenario_runner`'s
    `_emit_fold_health` unions the result with the existing `check` findings.
    The divergence bridge lives in its own tiny lib module
    `fold_health_runner.{ml,mli}` — extracted from `runner.ml` so both
    `runner.ml` (493) and `simulator.ml` (500) stay under the 500-line
    file-length hard limit.
  - **Additive / default-0:** a non-empty divergence finding only WARNs to
    stderr + lands in `fold_health.sexp` (same contract as the #1549 signatures
    — never fails the run). On healthy runs every open position is `Holding`, so
    the count equals the open-position count and the check is silent.
  - **Lives at:** `simulator.ml` (+`simulator_types.{ml,mli}`),
    `runner.{ml,mli}`, `fold_health_runner.{ml,mli}` (new), `scenario_runner.ml`.
  - **Tests:** `test_fold_health_runner.ml` (+3, runner path):
    divergence fires through `Fold_health_runner.divergence_findings` on a 2-open/1-eligible
    gap; silent when aligned (2/2); silent when flat (0/0). Existing 12
    `test_fold_health` pure tests + `test_result_writer` / `test_trade_audit_report`
    (result-fixture field added) stay green.
  - **Verify:** `dune runtest trading/backtest/test trading/simulation/test`.
  - **Branch:** `feat/fold-health-runner-wiring`. Links #1557.

## QC

Step 1 (PR #399, merged) — overall_qc APPROVED at e59f8d2 (both prior blockers U6/F1 and the BC4 advisory resolved; `_held_symbols` strategy fix domain-correct).

Step 2 (PR #419, ready for review):
- structural_qc: APPROVED (re-verification at 0381bde, 2026-04-18 run 4) — refactor-only delta from cc4edca6 (trace.ml sentinel→option, dropped `to_string`, simplified parsers; -23 net lines); fmt violation at 73f74c2 fixed by 0381bde.
- behavioral_qc: APPROVED (re-verification at 0381bde, 2026-04-18 run 4) — Trace is pure instrumentation plumbing; Weinstein domain axes remain NA; refactor preserves behavior.
- overall_qc: APPROVED (re-verification at 0381bde)

Step 2 of the scale-optimization plan complete on
`feat/backtest-phase-tracing` (PR #419). Adds a `Backtest.Trace` module
(`trading/trading/backtest/lib/trace.{ml,mli}`) with `Phase.t` (11
variants), a `phase_metrics` record, `record : ?trace -> Phase.t ->
(unit -> 'a) -> 'a`, and `write : out_path -> metrics -> unit`.
`Runner.run_backtest` gains an optional `?trace` argument (default off)
and instruments 5 coarse phases at the runner level: Load_universe,
Macro, Load_bars, Fill, Teardown. Finer-grained wraps for the per-bar
strategy phases (Sector_rank / Rs_rank / Stage_classify / Screener /
Stop_update / Order_gen) require strategy-level instrumentation and are
deferred (see §Follow-up). Step 2 unblocks the separately-tracked Step
3 tier-aware bar loader (`dev/status/backtest-scale.md`) by giving A/B
measurements a commit-stable sexp output format.

Step 1 (merged via PR #399) delivered the two-tier universe for
scenarios. Small-universe pinned at 300 symbols across all 11 GICS
sectors; broad-universe sentinel falls back to the full
`data/sectors.csv`. Goldens reorganised

**Environment note (2026-04-18):** the GHA `dev/lib/run-in-env.sh dune
build @runtest` target fails because the nesting linter reports 49
pre-existing violations (universe_filter, fetch_finviz_sectors, ad_bars)
— none introduced by this PR. `trading/backtest/lib/trace.ml` and
`trading/backtest/lib/runner.ml` are clean under the linter. The
pre-flight context said main exits 0; in this container it doesn't. The
PR's own targeted test command `dune runtest trading/backtest/test/`
passes with 0 warnings and all 19 cases green (10 new Trace tests + 6
Stop_log + 3 Runner_filter). Flagging for QC to confirm this is the
same pre-existing state seen elsewhere and not a regression.

Earlier on 2026-04-17 the per-scenario `unrealized_pnl` range pin landed
(feat/metrics-scenario-unrealized-pin, follow-up to merged #393). Before
that: UnrealizedPnl=0 bug fixed + CAGR docstring clarified via PR #393.
First experiment (stop-buffer) complete and REJECTED on golden — see
§Completed. Framework formalization still open; support-floor
experiment still blocked on `feat-weinstein` #382.

## Ownership
`feat-backtest` agent — see `.claude/agents/feat-backtest.md`. Owns
experiments + strategy-tuning features (stop-buffer tuning, drawdown
circuit breaker, per-trade stop logging, segmentation-based stage
classifier). Distinct from `feat-weinstein`, which owns the base
strategy code (currently complete).

## Landed (merged to main)

- `#195` — `strategy_cadence` on simulator config
- `#196` — Weinstein strategy `STRATEGY` implementation
- `#298` — Universe sort for partial determinism
- `#304` — Metric suite: ProfitFactor, CAGR, CalmarRatio, OpenPositionCount,
  UnrealizedPnl, TradeFrequency, plus base stats; derived metric computer
  pattern (`depends_on`)
- `#308` — Inline TODO slugs: `TODO(area/descriptive-slug)` anchored in status files
- `#311` — Metric computer split (each computer in its own file)
- `#312` — Sexp deriving on strategy config types (prereq for generic overrides)
- `#306` — `--override '<sexp>'` flags with generic deep-merge
- `#315` — Extract `backtest_runner_lib` from CLI; restructured into
  `trading/trading/backtest/{lib,bin}/` with `Backtest.{Summary,Runner,Result_writer}`;
  Summary uses `[@@deriving sexp_of]` with custom converters for `Money` and
  `Metric_set` to preserve human-readable formatting
- `#316` — Unified scenario runner with fork-based parallel execution
  - `trading/trading/backtest/scenarios/{scenario.ml,scenario_runner.ml}`
  - `Scenario` derives sexp (with custom range of_sexp and `[@@sexp.allow_extra_fields]`)
  - Fork pool; each child runs `Backtest.Runner` and writes `actual.sexp`; parent
    reads back and prints checks table in declaration order
  - Fixture files at `trading/test_data/backtest_scenarios/{goldens,smoke}/`

## Open PRs
- #853 `feat/15y-trade-count-investigation` — investigation note for
  16-trade 15y run; dominant cause = position-sizing × cash exhaustion.
  See `dev/notes/15y-trade-count-investigation-2026-05-05.md`. No code
  changes; recommendation queued.

Merged in main:
- #399 Step 1 (two-tier universe) — 2026-04-17.
- #393 unrealized_pnl pin fix — 2026-04-17.
- #395 per-scenario `unrealized_pnl` range check — merged 2026-04-17.
- #419 Step 2 (per-phase tracing) — 2026-04-19.

## Next Steps

- **Step 3 (tier-aware bar loader)** now unblocked; separately tracked at
  `dev/status/backtest-scale.md`. A/B the Legacy vs Tiered loader
  against a traced Legacy baseline. Do not pick up Step 3 from this
  track — it has its own status file and branch
  (`feat/backtest-tiered-loader`).
- **Per-bar phase instrumentation** (Sector_rank through Order_gen)
  can land as a follow-up without changing the trace sexp schema — the
  Phase variants are already defined. See §Follow-up item 6. Practical
  prerequisite: the Tiered loader flip (`backtest-scale.md`) — per-bar
  tracing is most valuable once broad-universe runs are cheap enough
  to iterate on. Pick this up once the Tiered flip lands.

## Baseline results (2026-04-13, pre-experiments)

| Scenario | Period | Return | Win Rate | Max DD | Sharpe |
|----------|--------|--------|----------|--------|--------|
| six-year | 2018-2023 | +57% | 28.6% | 34.0% | 1.28 |
| bull-crash | 2015-2020 | +305% | 33.3% | 38.7% | 0.79 |
| covid-recovery | 2020-2024 | +27% | 47.7% | 38.0% | 1.00 |

**Critical finding:** 74% of trades exit within 1 day (whipsaw). Stop buffer too tight.

## Performance

- 6-year / 1654 stocks: ~40 min, 7 GB RAM (single run)
- 6-month smoke: ~5 min
- Parallel scenarios (post-#316): N scenarios run concurrently as forked children;
  memory scales ~linearly with N because each child reloads universe data.
- Non-deterministic due to Hashtbl ordering (tracked, not fully fixed)

## Completed

- [x] **Stale/delisted position force-exit (default-off)** (2026-06-08,
  `feat/backtest`, issue #1484). `Trading_simulation.Stale_hold` was a
  detector only — a delisted/halted held position was carried open
  indefinitely, marked at its last available close, and counted in
  terminal NAV (8 of 9 terminal opens in a top-3000 PIT 15y run were such
  zombies; see `dev/notes/p0-verify-broad-universe-790-2026-06-08.md` §3).
  Added a **default-off** force-exit: `Stale_hold.config` gains
  `stale_exit_after_days : int option [@sexp.default None]` and a pure
  `force_exit_candidates` helper; `Weinstein_strategy.config` gains the
  same field (axis-able via `Overlay_validator`, flag-discipline R2);
  `Backtest.Panel_runner._make_simulator` threads it into the simulator's
  `Stale_hold.config`. When `Some n`, a held position whose bar gap ≥ n is
  force-sold at its last close as a **realised trade** (lands in
  `trades.csv` / realised PnL, frees cash) — applied in
  `Simulator._prepare_market_state`, only on bar-bearing days, and merged
  into the step's `trades`. `None` everywhere ⇒ byte-identical to pre-#1484
  (detector still records; no exit). Verify:
  `dune runtest trading/simulation/test/` (new `force_exit_candidates` +
  3 e2e simulator tests pinning realised-PnL = (last_close − avg_cost)×qty,
  flat-after, and the disabled-keeps-open path). Plan:
  `dev/plans/stale-position-force-exit-2026-06-08.md`.

- [x] **15y SP500 trade-count investigation** (2026-05-05, PR #853).
  Root-cause investigation: `goldens-sp500-historical/sp500-2010-2026.sexp`
  produced 16 trades over 16y vs ~264 expected. **Dominant cause:
  position-sizing exhausts $1M cash inside the first year (Day 1 commits
  $993K across 4 positions hitting the 30%-of-portfolio per-position cap),
  and 8 winners-that-never-stop tie up $0.95M cost basis for the
  remaining 15 years.** From 2012 onward 728 weekly cycles each find
  10-17 cascade-admitted candidates but every one is rejected on
  Insufficient_cash (skip-reason ratio 271:37 over Stop_too_wide in the
  24 audit entries). Hypotheses refuted with empirical numbers: sector
  "Unknown" filter, indicator warmup, regime, data gaps, Wiki-replay
  survivorship — none are dominant. Note at
  `dev/notes/15y-trade-count-investigation-2026-05-05.md`.
  Recommendation: scenario-level `config_overrides` on
  `sp500-2010-2026.sexp` only (`max_position_pct_long 0.30 → 0.05`,
  `min_cash_pct 0.10 → 0.30`) — preserves all other goldens' pinned
  baselines. Also flagged 3 side-issues for follow-up (equity_curve
  truncation, MRO-zombie in trades.csv ∧ open_positions.csv,
  progress.sexp 10x equity mismatch).
- [x] **Fuzz-runner CLI flag (`--fuzz <param>=<center>±<delta>:<n>`)**
  (2026-05-02, `feat/fuzz-runner`). Generic parameter-jitter mode for
  robustness testing — the same backtest run repeated N times with the
  named parameter swept across `[center - delta .. center + delta]`,
  with per-metric distribution stats (median, p25/p75, std, min, max)
  written alongside per-variant artefacts. Surfaces path-dependency vs
  robust-signal: a tight band across N runs says the metric is stable;
  a wide band says the single-run number is one draw from a noisy
  distribution.
  - New `Backtest.Fuzz_spec` (`trading/trading/backtest/lib/fuzz_spec.{ml,mli}`)
    parses the spec syntax and materialises N variants. Two value kinds:
    date (`start_date=2019-05-01±5w:11`, units `d`/`w`/`m`) and numeric
    (`stops_config.initial_stop_buffer=1.05±0.02:11`). Both `±` (UTF-8)
    and `+/-` (ASCII) accepted as separators. Linear spacing across
    `[center - delta, center + delta]` inclusive.
  - New `Backtest.Fuzz_distribution` (`trading/trading/backtest/lib/fuzz_distribution.{ml,mli}`)
    folds N labelled summaries into per-metric stats; sexp + markdown
    rendering. Percentiles use Type-7 linear interpolation (R/NumPy
    convention); std is sample (Bessel-corrected, n-1).
  - Wired into `backtest_runner.exe`: new `--fuzz <spec>` flag,
    mutually exclusive with `--baseline`/`--smoke`, requires
    `--experiment-name`. Composes with `--override` (those apply to
    every variant). Output structure:
    `dev/experiments/<name>/variants/var-NN/{summary,trades,...}` plus
    `fuzz_distribution.{sexp,md}` at the root.
  - Tests: 18 in `test_fuzz_spec.ml` (date+numeric specs, error paths,
    subdir naming), 8 in `test_fuzz_distribution.ml` (hand-pinned
    percentiles + stats), 7 added to `test_backtest_runner_args.ml`
    (flag wiring + exclusivity). All 60 backtest tests pass; nesting +
    fn-length + magic-number linters clean on all new files. Also
    exposes a small `val Comparison.metric_label` so the distribution
    module shares the same metric-name registry instead of duplicating
    it.

  Verify: `dune runtest trading/backtest/test`. Manual:
  `backtest_runner 2019-05-01 2019-12-31 --fuzz start_date=2019-05-01±5w:11 --experiment-name fuzz_demo`.

- [x] **Experiment-runner overrides + comparison + smoke catalog (M5.2a)**
  (2026-05-02, `feat/backtest-experiment-runner-overrides`). Wires three
  new flags into `backtest_runner.exe` so experiment runs become
  structured + comparable:
  - `--override key.path=value` — ergonomic key-path syntax, dispatched
    via new `Backtest.Config_override` (parses
    `stops_config.initial_stop_buffer=1.05` → partial-config sexp). The
    legacy `--override <sexp>` form keeps working; both compose freely.
  - `--baseline` — runs twice (default config + overrides), writes
    `comparison.sexp` + `comparison.md` showing per-metric deltas via
    new `Backtest.Comparison`. Output goes to
    `dev/experiments/<name>/{baseline,variant}/` with `comparison.*` at
    the experiment root.
  - `--smoke` — loops over the new `Scenario_lib.Smoke_catalog` (Bull
    2019-06–2019-12, Crash 2020-01–2020-06, Recovery 2023). Composes
    with `--baseline` for per-window comparisons.
  - `--experiment-name <name>` — required by the above two; routes
    output to `dev/experiments/<name>/`.

  Implementation: `backtest_runner_args` now stores overrides as
  `string list` (was `Sexp.t list`); the executable dispatches via
  `Config_override.is_key_path_form`. Override applies to exactly the
  named field — all other config sourced from default — pinned by
  the existing `_apply_overrides` deep-merge in `Runner`.

  New tests: 21 (Config_override) + 8 (Comparison) + 7 (Smoke_catalog)
  + 10 added to `test_backtest_runner_args` (27 total). All 251 tests
  in `trading/backtest/test/` pass; nesting + fn-length linters clean
  on all new files.

  Verify: `dune runtest trading/backtest/test`. Manual: `backtest_runner
  2019-06-01 2019-12-31 --baseline --override stops_config.initial_stop_buffer=1.05
  --experiment-name stop_buffer_test`.

- [x] **UnrealizedPnl rename + corrected metric** (2026-05-01,
  `feat/metrics-unrealized-pnl-rename`, PR #741). Bug surfaced via
  reconciler today: the existing `UnrealizedPnl` metric (=
  `final_portfolio_value - current_cash`) is the signed mtm value of open
  positions, not paper P&L vs cost basis. On a long-only sp500-2019-2023
  baseline that's $1,254K (mtm) vs a true paper P&L of +$422K. PR renames
  the existing metric to `OpenPositionsValue` (semantics preserved) and
  adds a NEW `UnrealizedPnl` computed as `OpenPositionsValue - Σ
  position_cost_basis` — equivalent to `Σ (current - entry) * signed_qty`
  (long: positive on gain; short: positive on price drop). All 13 scenario
  sexp pin keys renamed `unrealized_pnl` → `open_positions_value`
  (range preserved). New long / short / mixed-portfolio tests in
  `test_metrics.ml`. The reconciler-confusion source flagged in
  `dev/notes/short-cash-accounting-design-2026-05-01.md` is now closed.
  Verify: `dune runtest trading/simulation/test trading/backtest/scenarios/test`.

- [x] **Perf-sweep harness extension** (2026-04-23,
  `feat/backtest-perf-sweep-harness`). Wraps the existing C2 perf harness
  in a (N × T × strategy) sweep so future scaling investigations can read
  the slope of RSS / wall-time vs. universe size and run length, rather
  than rerunning a single-point hypothesis test for each variation. Four
  perf-sweep scenario sexps under
  `trading/test_data/backtest_scenarios/perf-sweep/{bull-3m,bull-6m,bull-1y,bull-3y}.sexp`
  use the broad universe sentinel so `--override '((universe_cap (N)))'`
  actually constrains the loaded set. Driver
  `dev/scripts/run_perf_sweep.sh` walks an 8-cell matrix (N=100/300/500/1000
  at T=1y plus T=3m/6m/3y at N=300 plus the 1000×3y worst corner), each
  cell × 2 strategies; skip-on-resume keys off non-empty
  `<strategy>.peak_rss_kb`; per-cell `timeout 1200` so a stuck cell
  doesn't hang the whole sweep. Aggregator
  `dev/scripts/perf_sweep_report.py` emits an RSS matrix, an N-sweep
  complexity table at fixed T=1y, a T-sweep complexity table at fixed
  N=300, a wall-time matrix, and a failure-section listing any cells
  that errored. Coarse linear-extreme-fit slope rows give the curve
  shape (sub-linear / linear / super-linear) without over-engineering
  the analysis. .gitignore extended with an explicit
  `dev/experiments/perf/sweep-*/` documentation pattern (already covered
  by the wildcard above). No production code touched. Verify:
  `bash -n dev/scripts/run_perf_sweep.sh`,
  `python3 -m py_compile dev/scripts/perf_sweep_report.py`,
  `dune build && dune runtest` (all green).

- [x] **Per-phase tracing (Step 2 of scale-optimization plan #396)**
  (2026-04-18, `feat/backtest-phase-tracing`, PR #419). New
  `Backtest.Trace` module (`trading/trading/backtest/lib/trace.{ml,mli}`)
  gives every backtest run a commit-stable phase-metrics sexp. Key shape:
  `Phase.t` has 11 variants (Load_universe / Load_bars / Macro /
  Sector_rank / Rs_rank / Stage_classify / Screener / Stop_update /
  Order_gen / Fill / Teardown); `record ?trace ?symbols_in ?symbols_out
  ?bar_loads phase f` runs `f ()` and appends one `phase_metrics` record
  with wall-clock elapsed_ms and best-effort peak_rss_mb (VmHWM from
  /proc/self/status). `?trace=None` is a no-op — callers wrap blocks
  unconditionally. `write ~out_path` emits a single sexp per run via
  `[@@deriving sexp]`, creating parent directories.
  `Runner.run_backtest` gains an optional `?trace` parameter and
  instruments 5 coarse phases at the runner level (Load_universe, Macro,
  Load_bars, Fill, Teardown — the first two inside `_load_deps`, the
  next two around `_make_simulator` and `_run_simulator`, Teardown
  around round-trip extraction + stop_infos gather). The 6 per-bar
  phases (Sector_rank through Order_gen) remain defined but not wired —
  they require strategy-level instrumentation inside `Simulator.run`
  and are a deliberate follow-up so Step 2 doesn't couple to a refactor
  of the simulator internals (see §Follow-up item 6). Output directory
  placeholder at `dev/backtest/traces/.gitkeep`. Ten OUnit2 cases under
  `trading/trading/backtest/test/test_trace.ml` cover `Phase.to_string`,
  sexp round-trip for all variants, `record` with ?trace=None
  passthrough, record with ?trace=Some recording (phase, counts,
  elapsed_ms >= 0), insertion order preservation, real elapsed
  measurement via busy-wait, and `write` + load_sexp round-trip with
  mkdir-p of a nested parent directory. Verify:
  `dev/lib/run-in-env.sh dune runtest trading/backtest/test/` (10 new
  tests).

- [x] **Related fix: strategy `_held_symbols` no longer includes Closed
  positions** (2026-04-17, `feat/weinstein-exclude-closed-from-held`).
  `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml:130`
  previously returned every `portfolio.positions` entry regardless of
  lifecycle state — including `Closed` — which permanently blacklisted
  every symbol the strategy had ever traded from re-entry via both
  `held_tickers` passed to `Screener.screen` and the in-strategy
  candidate filter. Replaced with an exhaustive match that keeps
  `Entering | Holding | Exiting` and drops `Closed`. Two unit tests
  added (mixed-state + all-Closed). Unblocks meaningful backtests;
  `test_weinstein_backtest` scenario counts now shift and will be
  re-pinned on `feat/backtest-scenario-small-universe` (PR #399). See
  `dev/notes/strategy-dispatch-trace-2026-04-17.md` / PR #408.

- [x] **Two-tier universe for scenarios (Step 1 of scale-optimization
  plan #396)** (2026-04-17, `feat/backtest-scenario-small-universe`,
  PR #399). Adds a `universe_path : string` field to `Scenario.t`
  (defaults to `universes/small.sexp` via `[@sexp.default]`, backwards
  compatible). New `Scenario_lib.Universe_file` module parses the file
  as `Pinned of pinned_entry list | Full_sector_map`. Small-universe
  fixture (`trading/test_data/backtest_scenarios/universes/small.sexp`)
  pins ~300 symbols across all 11 GICS sectors (≥8 sectors, ≥100
  symbols enforced by test); broad-universe fixture is the
  `Full_sector_map` sentinel that falls back to `data/sectors.csv`.
  Goldens reorganised: `goldens/` → `goldens-small/`; new
  `goldens-broad/` with three scale-regression variants (`six-year`,
  `bull-crash`, `covid-recovery`) pinning the same expected ranges as
  the 2026-04-13 baseline. `Backtest.Runner.run_backtest` takes a new
  optional `?sector_map_override` parameter; `Scenario_runner` bridges
  via `Universe_file.to_sector_map_override`. New CLI flags
  `--goldens-small` (default, local-friendly), `--goldens-broad`
  (nightly/GHA), `--goldens` alias. Reproducible selection script at
  `trading/backtest/scenarios/pick_small_universe/pick.ml` (stratified
  sampling over `Inventory.load` + hand-curated known-historical
  cases) with docs pointer at `dev/scripts/pick_small_universe/README.md`.
  16 tests (9 scenario + 7 universe_file). This unblocks Step 2
  (per-phase tracing) under this track and the parallel
  `dev/status/backtest-scale.md` Step 3 work (tier-aware bar loader).
  Verify: `dune runtest trading/backtest/scenarios/test`.

- [x] **UnrealizedPnl=0 bug + annualized-return clarification**
  (2026-04-16, `feat/metrics-unrealized-fix`) — see Follow-up items 1
  and 2 for full root-cause writeup. Fix: `portfolio_state_computer.ml`
  now tracks last mark-to-market step separately from last step, so
  `UnrealizedPnl` no longer collapses to 0 when the sim ends on a
  weekend. CAGR docstring clarified as the canonical annualized-return
  metric. Verify: `dune runtest trading/simulation/test` (metrics
  suite grew from 33 → 35 tests).
- [x] **Stop-buffer tuning experiment** — full smoke + golden complete.
  Smoke (recovery-2023, 1yr) looked strongly positive for wider buffers
  (1.15 → +38.9%, Sharpe 1.78). **Golden (2018-2023, 6yr) reversed the
  result**: 1.15 returned -7.1% with Sharpe -0.01; 1.02 control won
  cleanly (+36.3%, Sharpe 0.36, lowest DD). Hypothesis REJECTED. Default
  `initial_stop_buffer = 1.02` stays. Scenario files at
  `trading/test_data/backtest_scenarios/experiments/stop-buffer/`. Report
  at `dev/experiments/stop-buffer/report.md`. Outputs:
  `dev/backtest/scenarios-2026-04-14-222425/` (smoke) and
  `dev/backtest/scenarios-2026-04-14-225929/` (golden).
- [x] **Per-trade stop logging** (#350, 2026-04-15) — `Stop_log`
  observer + `Strategy_wrapper` capture stop levels and exit-trigger
  type on each transition; `Result_writer` emits `entry_stop`,
  `exit_stop`, `exit_trigger` columns in `trades.csv`. Unblocks
  post-mortem of individual whipsaw exits.
- [x] **Pin `unrealized_pnl` per scenario** (2026-04-17,
  `feat/metrics-scenario-unrealized-pin`, follow-up to merged PR #393)
  — adds
  `expected.unrealized_pnl : range option` via `[@sexp.option]` to
  `Scenario.expected`, with the runner computing
  `UnrealizedPnl` into the `actual` record and pattern-matching a 7th
  range check. Scenarios that don't declare the field get `None` and
  skip the check (preserves prior behaviour). Five scenarios now pin a
  non-zero range (`min > 0`, intentionally wide to absorb the
  universe-size flux tracked under follow-up #3): all three goldens
  plus `bull-2019h2` and `recovery-2023` smokes. `crash-2020h1` is
  intentionally left unpinned because a crash regime can plausibly
  liquidate the whole portfolio. Also split the `scenarios/` dune into
  a tiny `scenario_lib` library + executable so parsing/validation is
  unit-testable without running a backtest. New test file
  `trading/trading/backtest/scenarios/test/test_scenario.ml` covers
  six cases (absent/present field parse, sexp round-trip, non-zero
  range rejects 0, near-zero range accepts 0, all real scenario files
  under `trading/test_data/backtest_scenarios/` parse and at least one
  pins `min > 0`). Verify:
  `dune runtest trading/backtest/scenarios/test` (6 tests).

## In progress
None.

## Blocked on
- **Support-floor-based stops experiment** (next in Next Actions) requires a new primitive in `weinstein/stops/` — stop placement by prior correction lows. Owned by `feat-weinstein`. Per 2026-04-16 direction change in `dev/decisions.md`, feat-weinstein is dispatched on `feat/support-floor-stops`; track at `dev/status/support-floor-stops.md`. Once it lands, feat-backtest picks up the experiment as a config-override variant next run.

## Next Actions

### Stop-buffer follow-ups (pick one)

The single-parameter fixed-buffer approach is brittle across regimes.
Alternatives ranked by expected value:

1. **Support-floor-based stops** (Weinstein's actual prescription):
   place stops at prior correction lows. Adapts to each stock's structure.
2. **Regime-aware stops**: use `Macro.analyze` trend to pick buffer width
   (tighter in bear, wider in bull). Testable via existing macro output.

Per-trade stop logging landed in #350 — now available as a diagnostic
input for any of the above experiments.

### Immediate: experiment framework

Phase-1 wiring landed 2026-05-02 (see Completed §Experiment-runner
overrides + comparison + smoke catalog). The runner now supports
`--override key.path=value`, `--baseline`, `--smoke`, and
`--experiment-name`, with comparison artefacts written under
`dev/experiments/<name>/`. Formalization (per-experiment hypothesis.md
template, scenario-variant directory layout) still open — defer until
after running the first 1-2 real experiments through the new wiring so
the structure is informed by actual needs.

### Medium-term

- **Drawdown circuit breaker** (Weinstein Ch. 7 — 20% threshold) — new
  feature, order_gen side. See
  `TODO(backtest-infra/drawdown-circuit-breaker)` when added.
- **Experiment framework formalization** — once 1-2 experiments show the
  shape.
- **Token/cost tracking** (T3-E from harness.md) — unrelated to this track
  but listed here historically.

## Follow-up items (queued 2026-04-16)

0. ~~**BC4 — re-pin `goldens-small/*.sexp` expected ranges from real small-universe runs.**~~ **[x] RESOLVED 2026-04-17** — ranges re-measured against the 302-symbol small universe. Centers pinned (see each sexp's header block) with ±25% tolerance on counts/days, wide bands on ratios. Prior 1,654-symbol baseline preserved in git history. Broad-universe ranges separately flagged (see follow-up 5 below).

5. **~~Re-pin `goldens-broad/*.sexp` on GHA (top-N sentinel).~~ SUPERSEDED 2026-06-05 — migrate the broad regression cells off the top-N sentinel to PIT composition universes instead.** Plan + per-cell snapshot mapping: `dev/plans/goldens-broad-pit-migration-2026-06-05.md`.

   *Why the original plan was the wrong fix.* The broad goldens point `universe_path` at `universes/broad.sexp` (the `Full_sector_map` sentinel) + `((universe_cap (1000)))`, i.e. "load the live `data/sectors.csv` (now 10,513 rows and growing) and take the **first-1000 sorted**" (`runner.ml:_apply_universe_cap` → `List.take`). That universe is **not reproducible** — *which* 1,000 of 10,513 get selected shifts whenever `sectors.csv` changes (e.g. #1194's +40-symbol backfill on 2026-05-18, after the 2026-05-11 Cell-E re-pin). Re-pinning *that* universe just re-drifts: the cells were re-pinned twice (2026-04-29 long-only, 2026-05-11 Cell E) and drifted again. The `goldens-broad.yml` cron was never created, so they stayed `perf-tier: 4` on-demand-only and drifted silently.

   *Surfaced 2026-06-05* (incidentally, while reusing the covid cell's config for a separate dial eval — **nothing flagged it**): a flag-off reproduction of `covid-recovery-2020-2024` on current main returned **139.9% / 52.9% MaxDD** vs the pinned **294.5% / 38.6%** — far outside every `expected` band; the cell would fail today, unnoticed.

   *The fix.* Point the four cells (`covid-recovery-2020-2024`, `six-year-2018-2023`, `decade-2014-2023`, `bull-crash-2015-2020`) at the **PIT-clean composition snapshots** already committed under `goldens-custom-universe/composition/` (`top-1000-<window-start-year>.sexp` — frozen, survivorship-correct [contain SIVB/FRC/BBBY/LEH/AIG], tradeable; the `universe_snapshot` consumer + `golden-runs-custom-universe` CI already run this kind of cell), drop `((universe_cap ...))`, re-pin once on current main, and CI-gate them. This **retires** the perpetually-deferred top-N re-pin instead of doing it a third time, and moves the cells onto the maintained per-PR/scheduled path so a future drift fails CI rather than surfacing by accident.



1. ~~**Verify unrealized gain is meaningful in `summary.sexp`.**~~ **[x]
   RESOLVED 2026-04-16** — bug confirmed, fix landed on
   `feat/metrics-unrealized-fix`. Root cause: the simulator produces a
   `step_result` every calendar day, but `_compute_portfolio_value`
   (at `trading/trading/simulation/lib/simulator.ml:123-134`) falls
   back to `portfolio_value = current_cash` whenever any portfolio
   position's price bar is missing for that date — including all
   weekend/holiday steps. The portfolio-state computer was using the
   absolute last step, which in 6-year backtests ending 2023-12-31
   (Sunday) is 2023-12-30 (Saturday) — a non-trading day, hence
   `portfolio_value == current_cash` and `UnrealizedPnl = 0` even with
   `OpenPositionCount = 3`. Fix: track a `last_marked_step` alongside
   `last_step`; `UnrealizedPnl` derives from the last mark-to-market
   step (same heuristic as `Backtest.Runner._is_trading_day` at
   `trading/trading/backtest/lib/runner.ml:28-36`); `OpenPositionCount`
   still uses the absolute last step (positions are independent of
   price-bar availability). Two new unit tests at
   `trading/trading/simulation/test/test_metrics.ml` lock in the
   behaviour. Verify: `dune runtest trading/simulation/test` → 35
   metrics tests pass.

2. ~~**Add annualized-return metric for apples-to-apples comparison
   across scenarios.**~~ **[x] RESOLVED 2026-04-16** — picked option
   (a). CAGR already *is* the annualized-return metric — it's the
   constant yearly rate that compounds initial to final portfolio
   value over the backtest period. Clarified the docstring in
   `trading/trading/simulation/lib/types/metric_types.ml:144-154` to
   state this explicitly so future readers don't re-queue this. No
   second metric added; no code behaviour change.

3. **Rerun smoke + golden simulations once the Finviz sector mapping
   is promoted.** The 2026-04-14 stop-buffer results were produced
   against `data/sectors.csv` = 1,654 symbols. The live Finviz scrape
   has that file at ~9,000 and the Item 4 universe filter
   (#368) brings it back down to ~4,916 with different composition.
   Screener behavior depends on sector-map coverage, so the baseline
   and all published experiment deltas may shift. After #368 lands
   and the filtered CSV is promoted: re-run `smoke/recovery-2023.sexp`
   and all three `golden/six-year-2018-2023` buffer variants, compare
   against the 2026-04-14 numbers in
   `dev/experiments/stop-buffer/report.md`, update the report with a
   post-sector-expansion addendum.

4. **Consolidate "what data range do we have" into one document.**
   Today it's scattered:
   - Per-symbol price bar ranges live in `data/inventory.sexp` (fields
     `first_date` / `last_date` per symbol).
   - ADL Unicorn history documented in `dev/notes/adl-sources.md` as
     1965-03-01 → 2020-02-10.
   - Synthetic ADL coverage (post-2020-02-11) documented implicitly
     in the composition rule in `trading/weinstein/strategy/lib/ad_bars.mli`.
   - Sector ETFs cached in `data/<letter>/<XL...>/` but no aggregated
     range.
   - Global indices (FTSE/DAX/Nikkei) — per-symbol only.
   Add `dev/notes/data-coverage.md` with a single table: dataset →
   source → range → last refreshed. Written once, refreshed from
   `data/inventory.sexp` by a small script run from the ops-data agent.
   Makes it obvious at a glance when a backtest's requested window
   exceeds available data for some input.

6. **Per-bar phase instrumentation (follow-up to PR #419).** The
   `Backtest.Trace` module (Step 2 of the scale-optimization plan)
   defines 11 `Phase.t` variants but the runner only wraps 5 coarse
   phases (Load_universe, Macro, Load_bars, Fill, Teardown). The
   remaining 6 (Sector_rank, Rs_rank, Stage_classify, Screener,
   Stop_update, Order_gen) are per-bar strategy phases that happen
   inside `Simulator.run` → `Weinstein_strategy.on_market_close`; wrapping
   them requires a small cross-cut inside the strategy or a tap point on
   the simulator's per-step callback. Deferred to keep PR #419 focused.
   Suggested approach: extend `Strategy_wrapper.wrap` with an optional
   `?trace` and have it wrap the strategy's `on_market_close` at the
   inner function boundaries where the screener cascade and stop update
   run. Trace sexp schema does not change — just more entries per run.
   Unblocks: detailed A/B of the Legacy vs Tiered bar loader (Step 3).

## Potential experiments (cross-functional — need feature work before runnable)

These have trading-behaviour impact but require upstream feature work before
they can be framed as a scenario variant. Owner-wise they straddle feature
tracks; tracked here so the planner sees the experiment end-state.

1. **Wider sector coverage** — filling in sector/industry for more of the
   universe (see `dev/status/data-layer.md` §Sector coverage expansion).
   Changes which symbols pass the `Sector` screener filter. **Hypothesis**:
   broader coverage → more qualifying Stage-2 candidates → different
   portfolio composition and possibly different win rate. Feature work
   needed: scrape + cache sector/industry (e.g. from Finviz).

2. **Universe composition cleanup** — drop mutual funds + low-volume ETFs
   (see `dev/status/data-layer.md` §Universe composition cleanup).
   **Hypothesis**: removing instruments that never pass the volume filter
   anyway should be a no-op on trade outcomes but speed up the simulation.
   Good sanity check that the filter is doing its job. Feature work
   needed: `universe_filter.ml`.

3. **Segmentation-based stage classifier** — piecewise linear regression
   on the MA series (already tracked in `dev/status/screener.md`
   §Followup). **Hypothesis**: fewer false stage-direction flips from
   short-term noise → steadier Stage 2 identification → fewer whipsaw
   exits. Feature work needed: swap `_compute_ma_slope` for
   `Segmentation.classify`. High likelihood of trading-behaviour
   improvement — ranks alongside stop-buffer tuning.

4. **Simulation performance** — not a trading-behaviour experiment but
   unblocks cheaper sweeps. See `dev/status/simulation.md` §Follow-up.

## Backtest Analysis TODOs (from dev/backtest/analysis.md)

1. **Stop placement** [HIGHEST IMPACT] — test wider stops and
   support-floor-based stops. **← this is the first experiment above.**
2. **Stop analysis logging** — per-trade stop level and trigger info in
   trades.csv
3. **Drawdown circuit breaker** — 20% threshold
4. **Portfolio health metrics** — partially done (#304 merged:
   OpenPositionCount, UnrealizedPnl)
5. **Segmentation for stages** — test trend segmentation library

## Harness items

- T2-B: Reference backtest config — landed via `test_data/backtest_scenarios/`
- T3-E: Token/cost tracking — not started (out of scope for this track)
