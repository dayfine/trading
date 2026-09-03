# Track: post-run-validation

## Status

IN_PROGRESS

<!-- 2026-07-13 orchestrator reconcile: heading was READY_FOR_REVIEW but v1
     harness (#1937) + C6b audit-join-by-position_id (#1947) are both MERGED
     with no open PR. Remaining follow-ups (golden-run V3/V4/V7 integration
     test, live-side reuse) are data-gated / LOCAL → track stays IN_PROGRESS. -->


## Owner

feat-backtest

## Summary

A read-only **post-run trade validator** (v1, report-only) that consumes a
completed scenario run's artifacts (`trades.csv`, `trade_audit.sexp`,
`open_positions.csv`) plus the per-symbol bar store, checks every trade against
15 declared invariants / expectations (V1-V15), and emits a validation report
(`<out>.sexp` + human `<out>.md`).

Derived from the 2026-07-12 visual trade audit
(`dev/notes/visual-trade-audit-2026-07-12.md`), which found the W12 bear-rally
loss class (COO/ANF/ASTE/AIR/TFX/OLED/STRA/BF-B) and several export defects.
Design: `dev/plans/post-run-validation-2026-07-12.md`. User directive: "we
should have some kind of post-backtest validation to verify the invariants /
expectations so we never make these kinds of trades again."

## Surface

- `trading/trading/backtest/validation/lib/validator_{types,step,artifacts,
  row_checks,bar_checks,splice_check,checks,report}.{ml,mli}` — 15 pure check
  functions over parsed rows + injected lookups, plus a `run` orchestrator.
- `trading/trading/backtest/snapshot_warehouse/splice_detector.{ml,mli}` — the
  build-time sibling of V15: a pure within-symbol continuity scan, wired
  default-off + report-only into `build_scenario_snapshots`.
- `trading/trading/backtest/validation/bin/post_run_validator_cli.ml` — CLI
  (`-run-dir -data-dir [-config] -out`).
- `trading/trading/backtest/validation/test/test_post_run_validator.ml` — unit
  tests for V1-V15 (except the armed-only V3/V4 real-artifact path),
  audit-join + severity/validate wiring, plus the `bars_of_daily` price-basis
  pin (62 tests).

## Checks (V1-V15)

| id | class | catches |
|---|---|---|
| V1 | INVARIANT | LONG entry stage not Stage2 (spine S6) |
| V2 | INVARIANT | LONG entry under Bearish macro (spine C2) |
| V3 | INVARIANT | entry-week dollar-ADV below `min_entry_dollar_adv` (armed only) |
| V4 | INVARIANT | open position with no bars for > `stale_exit_after_days` (armed only) |
| V5 | INVARIANT | exit_trigger vs stop_trigger_kind inconsistency (export-join defect) |
| V6 | INVARIANT | rename-twin duplicate positions (NLS/BFX) |
| V7 | INVARIANT | Virgin_territory label with < `virgin_lookback_bars` history (COO class) |
| V8 | EXPECTATION | LONG entry with Declining MA (AIR class) |
| V9 | EXPECTATION | entry beneath overhead supply within +`overhead_pct` (W12 bear-rally class) |
| V10 | EXPECTATION | entry-week vertical spike > `spike_pct` (FNMA spike-chase class) |
| V11 | EXPECTATION | stop_initial_distance_pct outside configured bounds |
| V12 | INVARIANT | installed stop wider than the `Stop_too_wide` gate would allow |
| V13 | INVARIANT | fill dated on a day with no bar, or priced outside that bar's `[low, high]` (arc §D1 Saturday exits) |
| V14 | EXPECTATION | `stop_loss` exit within 1 bar of entry whose entry-day close sat on the safe side of the installed stop (arc §D2) |
| V15 | EXPECTATION | round trip with `\|pnl_pct\| > 100%` held <= 5 days whose entry or exit bar's `adjusted_close` jumped outside `[0.4, 2.5]` vs the prior bar — a data splice, not a trade (issue #2646, CHS) |

v1 is **report-only** (exit code always 0). Severity default: V1-V7 + V12/V13
INVARIANT, V8-V11 + V14/V15 EXPECTATION; every check's severity is
config-overridable
(`severity_overrides`), which is the EXP→INV promotion path as prevention gates
(declining-MA, overhead-resistance) get armed.

## Verify

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune build trading/backtest/validation/ && \
   dune runtest trading/backtest/validation/'
```

## Fixes

- [x] **C6b: audit join rekeyed by `position_id`** (feat/validator-audit-join).
  The join keyed `trade_audit.sexp` records to `trades.csv` rows by
  `(symbol, entry_date)`, but audit records carry the SIGNAL Friday while rows
  carry the FILL date — the lookup missed 100% of rows, silently skipping
  V1/V2/V7/V8 (reported "PASS (N skipped)"). Now `build_audit_lookup` joins on
  the `position_id` column (#1942, trailing column) when present, falling back
  to `symbol|entry_date` for legacy 19-column runs. Report + CLI now print
  `audit join: N/M rows matched` so a dead join can't masquerade as PASS.
  Verify: `dune runtest trading/backtest/validation/test/` (join tests:
  `join_by_position_id_survives_date_skew`,
  `join_legacy_falls_back_to_symbol_date`, `audit_join_coverage_counts`).

- [x] **V13 + V14: execution-causality checks** (feat/validator-v13-v14).
  V1-V12 all reason about the entry DECISION; none could see whether the
  resulting FILL is physically possible, so both arc-run defects
  (`dev/experiments/arc-rerun-2026-09-01/README.md`, landing in PR #2645;
  §D1 Saturday-dated exits at
  the prior Friday's open; §D2 one-day stop-losses whose entry bar closed above
  the stop) had to be found by hand. V13 (INV) pins bar existence on
  `entry_date`/`exit_date` plus fill-price-in-`[low, high]`; V14 (EXP) flags a
  prompt `stop_loss` whose entry-day close sat on the safe side of the
  reconstructed stop. `bars.daily` now carries raw OHLC (the basis the
  simulator fills against) instead of `(date, close, volume)`; new config knobs
  `fill_price_epsilon_pct` (1e-6) and `entry_bar_stopout_max_bars` (1), both
  `[@sexp.default]` so existing validator configs keep parsing. A price leg
  waived by the basis guard reports `Skip`, not `Pass`, so it stays counted in
  `n_skipped`. Verify: `dune runtest trading/backtest/validation/test/` — 22
  V13/V14 cases (7 V13 + 15 V14), covering the two headline defect shapes, both
  sides of the `entry_bar_stopout_max_bars` window (including the
  `bars_in_window` Friday-to-Monday = 1 / Saturday = 0 semantics), the E-basis
  `stop_initial_distance_pct` fallback and its preference order, the SHORT
  mirror of both V14 outcomes, the re-based-store price-leg waiver in both
  directions, and every documented Skip branch of both checks — absent symbol,
  empty daily array, and basis mismatch each pinned separately for V13 and for
  V14, with V14's missing-stop-column and no-entry-bar branches sharing one
  match arm and so one case. Each Skip branch was verified by mutating it to
  `Pass` and confirming a test goes red.

- [x] **V15 + a build-time warehouse continuity gate** (feat/splice-gate-2646,
  issue #2646). `CHS` 2004-12-17 -> 2004-12-20 stepped from an **adjusted**
  close of 4.0693 to 15.8803 (x3.9) on volume ~5M -> ~1M, with the raw close
  moving x4.0 — the adjustment factor barely changes, so no split is
  recoverable and from that bar the series is a different security under a
  recycled ticker. The arc's volume-eject bought Friday and "sold" Monday for
  **+$513,550 on a three-day hold**: 70% of the g00-fix cell's realised P&L,
  and enough to flip the sign of the 26y fix-armed cell. V13/V14 could not see
  it — every bar exists and every fill is inside its bar's range; the bars are
  simply the wrong company's.
  - **V15 (EXP)**, `validator_splice_check.check_v15`: a round trip that is
    both implausibly profitable and implausibly brief (`|pnl_pct| >
    splice_pnl_pct_threshold`, default 100.0, held at most
    `splice_max_days_held`, default 5 calendar days) whose entry **or** exit
    bar's `adjusted_close` moved by a factor strictly outside
    `[splice_adj_ratio_min, splice_adj_ratio_max]` (0.4 / 2.5) against the
    immediately preceding daily bar. The ratio is on the **adjusted** series so
    ordinary splits — which move the raw close and leave the adjusted one
    continuous — cannot flag. All four knobs are `[@sexp.default]` config
    fields, so existing validator configs keep parsing. `bars.daily` gains an
    `adjusted_close` field (its only non-raw column) to carry the series.
  - **`Splice_detector`** (`trading/trading/backtest/snapshot_warehouse/
    splice_detector.{ml,mli}`), a pure sibling of `Twin_detector`: that pass
    compares whole series *across* symbols to find one company listed twice,
    this one compares consecutive bars *within* one symbol to find two
    companies listed once. Neither sees the other's defect — the CHS splice sat
    in a warehouse the twin pass had already cleaned. When a candidate day's
    raw-vs-adjusted divergence snaps to a small rational,
    `Types.Split_detector.detect_split` recovers it and the finding is
    suppressed (`skip_split_days`, default true) — this only fires on a feed
    carrying an un-back-rolled corporate action, since a correctly adjusted
    split never becomes a candidate at all.
  - **Wiring is default-off and report-only** (`experiment-flag-discipline.md`
    R1): `build_scenario_snapshots -detect-splices` (plus `-splice-min-ratio`,
    `-splice-max-ratio`, `-splice-include-split-days`) writes
    `<warehouse>/splices.csv` in the committed scan's exact columns and
    precision, and `_scan_splices` returns `unit` — no symbol is dropped and no
    bar truncated whatever it finds. Unarmed, the builder is bit-identical to
    its pre-#2646 behaviour. A `truncate_at_splice`-style action, if ever
    wanted, is a separate default-off flag.
  - Verify: `dune runtest trading/backtest/validation
    trading/backtest/snapshot_warehouse` — 14 V15 cases (the CHS specimen and
    its SHORT mirror, a legitimate +120%/4-day trade on continuous bars, a
    correctly adjusted 4:1 split whose **raw** close steps x0.25 while the
    adjusted one holds — clean only because the ratio is on the adjusted
    series, both ends of the ratio band at and just past the bound, the
    entry-leg collapse, both halves of the candidate predicate, the
    config-routed band, and all five documented Skip branches) plus one
    `Validator_artifacts.bars_of_daily` case pinning that the loader keeps the
    raw OHLC and the adjusted close on separate bases, plus 18
    `Splice_detector` cases (including a correctly adjusted 4:1 split that
    stays clean *even with the guard disabled*, and a late-back-rolled 3:1 that
    is clean only *because* of the guard). Every V15 Skip branch was
    mutation-verified — each rewritten to `Pass` (or, for the non-positive
    prior `adjusted_close`, deleted outright) with a test confirmed red — as
    were both halves of the adjusted-vs-raw basis contract: reading `close` in
    `_v15_ratio`, and populating `adjusted_close` from `close_price` in the
    loader.

## Follow-ups

- Run V15 over the arc run as first acceptance: expect the CHS specimen to
  reproduce, and cross-check the flagged set against the 184 tradeable rows in
  `dev/experiments/arc-rerun-2026-09-01/results/splice-scan-tradeable.csv`.
- Re-run any g00 / 2004-window arc result ex-CHS before citing it (issue #2646
  ask 3) — still open; V15 makes the artifact detectable, it does not restate
  the affected numbers.
- Arm `-detect-splices` on the next warehouse rebuild and review `splices.csv`
  before deciding whether a truncate-at-splice action is worth building.
- Wire `scenario_runner --validate` post-step (out of scope for v1 per plan).
- Promote V14 to INVARIANT via `severity_overrides` once the entry-bar stop
  evaluation is fixed and its expected count is 0.
- Run V13/V14 over the arc run as first acceptance: expect the §D1 and §D2
  counts to reproduce (2,500+ and 173 respectively).
- Add a golden-run expected band (all invariants zero) once gates are armed.
- Live-side reuse: run the same checks against a weekly picks snapshot before
  the report is trusted (deployment checklist item).
- V3/V4/V7 real-artifact coverage: unit-tested checks are V1/V2/V5/V6/V9/V10/V11;
  the bar-dependent V3/V4/V7 are covered structurally but want a golden-run
  integration test.

## Last updated: 2026-09-03

## Interface stable

NO
