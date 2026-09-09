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
18 declared invariants / expectations (V1-V18), and emits a validation report
(`<out>.sexp` + human `<out>.md`).

Derived from the 2026-07-12 visual trade audit
(`dev/notes/visual-trade-audit-2026-07-12.md`), which found the W12 bear-rally
loss class (COO/ANF/ASTE/AIR/TFX/OLED/STRA/BF-B) and several export defects.
Design: `dev/plans/post-run-validation-2026-07-12.md`. User directive: "we
should have some kind of post-backtest validation to verify the invariants /
expectations so we never make these kinds of trades again."

## Surface

- `trading/trading/backtest/validation/lib/validator_{types,step,artifacts,
  row_checks,bar_checks,splice_check,fallback_check,store_check,checks,report}
  .{ml,mli}` — 18 pure check functions over parsed rows + injected lookups, plus
  a `run` orchestrator.
- `trading/trading/backtest/snapshot_warehouse/splice_detector.{ml,mli}` — the
  build-time sibling of V15: a pure within-symbol continuity scan, wired
  default-off + report-only into `build_scenario_snapshots`.
- `trading/trading/backtest/validation/bin/post_run_validator_cli.ml` — CLI
  (`-run-dir -data-dir [-config] -out`).
- `trading/trading/backtest/validation/test/test_post_run_validator.ml` — unit
  tests for V1-V15 (except the armed-only V3/V4 real-artifact path),
  audit-join + severity/validate wiring, plus the `bars_of_daily` price-basis
  pin (62 tests).
- `trading/trading/backtest/validation/test/test_validator_{fallback,store}_check
  .ml` — V16/V17 (14 tests) and V18 (17 tests).

## Checks (V1-V18)

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
| V16 | EXPECTATION | round trip closed by a fallback safety net rather than a strategy rule (`fallback_exit_labels`; `delisted` deliberately excluded) |
| V17 | EXPECTATION | entry filled more than `stale_entry_days` (7) after the symbol's last bar — priced against a dead series (#2687, CY) |
| V18 | EXPECTATION | symbol whose median close exceeds `store_median_close_max` ($10k), or whose close moved more than `store_zero_volume_move_pct` (90%) in one bar on volume <= `store_zero_volume_max` (0) — a mis-scaled or phantom series, not a price (issue #2732, MEL) |

v1 is **report-only** (exit code always 0). Severity default: V1-V7 + V12/V13
INVARIANT, V8-V11 + V14-V18 EXPECTATION; every check's severity is
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

- [x] **V18: store-level series sanity** (feat/backtest/v18-store-sanity,
  issue #2732 ask 2). `data/M/L/MEL/data.csv` in the top-3000-2000 vintage is
  not a US equity price series: 2,353 of 2,427 bars close above $1,000
  (2017-01 around $167k-177k) with a handful of $8-12 bars mixed in on
  near-zero volume, and `adjusted_close` tracks `close` so no split explains
  it — a foreign/OTC listing mis-mapped onto the MEL ticker. An arm bought
  **1 share at $175,002** on 2017-01-30 (at that price one share IS the
  ticket) and the 12.2 print on 2017-02-08, volume 0, gapped it through the
  stop for **-$171,654, -99.99%**; the canonical 26y record carries a MEL
  trade. No existing check could see it: every bar exists, every fill is
  inside its bar's range (V13 clean), and V15 only inspects the two bars
  around a fill.
  - **V18 (EXP)**, `validator_store_check.check_v18`, a new module rather than
    an addition to `validator_bar_checks` — it follows the V15 precedent
    (a question about the bar store's own integrity, not about a strategy
    decision or a fill) but reads the whole per-symbol series rather than the
    two bars around a fill. Two independent rules, either alone flagging:
    median daily close above `store_median_close_max` (10,000.0), or a one-bar
    close move beyond `store_zero_volume_move_pct` (90.0, strict) on volume at
    or below `store_zero_volume_max` (0). All four knobs plus `store_min_bars`
    (20) are `[@sexp.default]` config fields, so existing validator configs
    keep parsing.
  - The unit of evaluation is the **symbol**, deduped across `trades` and
    `open_positions` and keyed to the earliest date the run put capital in, so
    a symbol traded ten times yields one specimen rather than ten crowding the
    10-specimen cap. The specimen names the median, the series span, and — when
    the phantom rule fired — the offending bar's date, close, prior close and
    volume, so `V18: 1 violation` is never the whole story a reader gets.
  - **EXPECTATION, not INVARIANT, by design**: the level rule flags a
    legitimately high-priced instrument (BRK.A trades above $400k), and no
    test separates "mis-mapped listing" from "expensive share class" from the
    price series alone. It asks a human; a run that legitimately holds one
    raises the ceiling rather than disabling the check. Both directions are
    pinned in the tests.
  - Skips are counted, never silently passed (V13's discipline): symbol absent
    from the store, fewer daily bars than `store_min_bars`, or a phantom scan
    that found nothing but could not evaluate every pair (a non-positive prior
    close admits no ratio). A violation outranks an un-evaluable pair.
  - Verify: `dune runtest trading/backtest/validation/` — 17 V18 cases: the MEL
    specimen and its exact detail string, one-row-per-symbol, open-position
    coverage, the phantom rule alone in an ordinary series, **the same -95%
    move on real volume passing** (the load-bearing negative — without it V18
    would flag a large slice of every broad-universe run), an ordinary series
    passing, the accepted BRK.A false positive and its config escape hatch, all
    three thresholds routed through config, and every documented Skip branch.
    The volume guard was mutation-verified: removing it turns exactly the three
    volume-dependent tests red.

## Follow-ups

- Quarantine MEL from the 2000 vintage, or re-fetch and validate the series
  (issue #2732 ask 1) — V18 makes the artifact detectable, it does not remove
  it or restate any affected number. Ask 3 (re-run the item-3 cells after the
  #2730 twin dedupe) likewise still open.
- Run V18 over the canonical 26y record as first acceptance: expect MEL to
  reproduce, and review whatever else the level rule surfaces to calibrate
  whether $10,000 is the right ceiling for a broad universe.
- Build-time sibling for V18, as `Splice_detector` is for V15: the same two
  rules run over the whole warehouse at build rather than over the symbols one
  run happened to touch, which is the other half of issue #2732 ask 2 ("the
  vintage build / post-run validator"). Deliberately out of the V18 PR to keep
  it to one new module.
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
