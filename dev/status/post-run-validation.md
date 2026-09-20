# Track: post-run-validation

## Status

READY_FOR_REVIEW

<!-- 2026-09-20: PR #2875 (wire Series_level into Build_runner behind
     -detect-series-level, report-only + default-off) is open and green, so the
     track carries an open PR awaiting QC. The 2026-07-13 reconcile note below
     still applies to the OTHER follow-ups — they are data-gated / LOCAL /
     operational, not dispatchable — so once #2875 merges with no successor PR
     this reverts to IN_PROGRESS. -->

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
- `trading/analysis/weinstein/snapshot_pipeline/lib/series_level.{ml,mli}` —
  the build-time sibling of V18's **level** rule: a pure per-symbol
  classification of a stored series' price level, beside `Series_tail` and
  `Series_splice`. Default-off, report-only, no action type; armed inside
  `Build_runner.build` via `Level_pass` below (PR #2875).
- `trading/analysis/scripts/build_snapshots/level_pass.{ml,mli}` — the CLI flag
  block + `series_level.csv` sidecar writer that arms `Series_level` inside
  `Build_runner.build`. Default-off, report-only; `Twin_pass`' module shape,
  `-detect-splices`' contract.
- `trading/analysis/scripts/build_snapshots/test/test_build_runner_level.ml` —
  end-to-end wiring pin for that flag (12 tests).
- `trading/trading/backtest/validation/test/test_series_level_v18_median_agreement.ml`
  — cross-module drift detector for the one statistic V18 and `Series_level`
  each compute their own copy of (3 tests).
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

- [x] **Build-time sibling of V18: `Series_level`**
  (feat/backtest/build-time-store-sanity, issue #2732 ask 2, second half).
  `trading/analysis/weinstein/snapshot_pipeline/lib/series_level.{ml,mli}` —
  a pure, report-only classification of a stored series' **price level**,
  beside `Series_tail` and `Series_splice`. `Config.enabled` defaults to
  `false`; the module has no action type and never edits a series.
  - **The residual was established before anything was built, and it is
    narrower than the follow-up assumed.** Both existing build-time modules
    key on a *discontinuity* — `Series_splice` on an adjusted-close ratio
    outside `[0.4, 2.5]`, `Series_tail` on a *terminal* run below
    `ratio × reference` — and their shared `misscale_close` (1,000.0) is a
    reclassifier applied to a series that already tripped a shape rule, never
    a primary level test. `Series_tail.Class.Prefix_misscale` is reachable
    only *through* the terminal-run test. So the residual is exactly: an
    implausible level with no discontinuity the shape rules can act on.
  - Three evidenced sub-classes. (i) **Seam outside the build window**:
    `Build_runner._clean_tail` runs `Series_tail` on the *windowed* bars and
    the splice scan uses the same window, so a window ending before a symbol's
    seam stores the mis-scaled prefix alone with nothing to key on — AGR
    2006-07-03, SGY 2003-09-09, DRL 2003-09-30, TEK_old 2007-02-26, SBER
    2007-07-17, LJPC 2008-12-17, BYDDY 2009-12-28. **The blindness here is
    certain at the code level; a present-day instance is not** — all three
    committed vintages run to 2026, so every seam listed is *in*-window for
    them and none of those seven symbols would flag on today's warehouse.
    Sub-class (ii) below is the instance-verified one. Consequence for the
    first armed report: it may carry **no** `Whole_window` row at all, and an
    empty one is the expected result rather than broken wiring.
    (ii) **The short-tail guard
    refuses the cut**: `misscale_min_kept_bars` (250) stores the series *whole*
    when the real segment is shorter — PEGX 210, CGE 180, TNT 44, **HTV 21**
    bars in `dev/experiments/warehouse-dedup-2026-09-08/results/
    terminal_runs_*_v10.csv`, all `action=kept`. (iii) **Scope**: V18 examines
    only symbols a run traded or held; a build pass sees all 2,908.
  - **Two halves of V18 deliberately not moved**, because they are already
    covered: MEL itself (98 splice findings → `Interleaved` → dropped), and
    the phantom-print rule (a >90% move is a ratio outside `[0.4, 2.5]`, so
    `Splice_detector` already reports every such bar *with* its volume). Only
    the **level** rule was ever the residual, and the non-coverage is pinned
    by a test so it reads as a decision.
  - Reported rows sub-classify into `Whole_window` (every bar above the
    ceiling — no seam, so no cut can help and a reviewer's only options are
    drop or raise the ceiling) and `Mixed_scale` (seam in-window — cross-read
    `terminal_runs.csv` / `splice_actions.csv` first, since a cut that keeps
    the real segment beats a drop). Sub-classifying rather than *narrowing*
    is deliberate: V18's reviewer argued down a max/min-ratio refinement on
    false-negative grounds, and `Whole_window` is the case that proves them
    right — a uniformly mis-scaled series has a max/min ratio near 1.0.
  - Ceiling defaults to V18's `store_median_close_max` (10,000.0), not the
    siblings' `misscale_close` (1,000.0): as a *median over a whole series*
    the latter would sweep in NVR / AZO / BKNG / pre-split AMZN and CMG (CMG's
    genuine $3,283.04 close is already a committed `prefix_misscale` row). The
    median *function* is byte-identical to `_v18_median_close`, and their
    agreement is now pinned by a cross-module test rather than asserted —
    `trading/backtest/validation/test/test_series_level_v18_median_agreement.ml`
    feeds one bar set to both halves and compares, including at even length
    with differing central closes. **The agreement is about the function, not
    the whole check**: the two halves feed it different inputs — `Series_level`
    drops non-finite closes before any statistic and counts only the survivors
    against `min_bars`, V18 sorts the stored array raw and counts all of it —
    so on a NaN-carrying series the two medians differ by construction
    (`Float.compare` orders `nan` below every real price). The claim holds for
    finite series, which is every series the scans produced. BRK.A still
    flags, inherited from V18.
  - Verify: `dune runtest --force analysis/weinstein/snapshot_pipeline/test/`
    — 18 cases; plus 3 in the cross-module drift suite under
    `dune runtest --force trading/backtest/validation/test/`.
    Mutation-verified, each measured red then green on revert: replacing the
    `n_above = n_bars` predicate with a constant reddens the classification,
    summary and drop-candidate tests; dropping the even-length mean from
    `_median_close` reddens the ceiling-boundary case and the drift suite's
    differing-central-closes case; loosening the ceiling test to `<` reddens
    the ceiling-boundary case; counting `>=` the ceiling, or classifying on
    `n_above >= n - 1`, reddens the one-bar-at-the-ceiling case; removing the
    `Int.max 1` floor on `min_bars` raises `Invalid_argument` in the
    empty-series case.
  - **Not wired to anything yet** at the time it shipped, deliberately; wired by
    the entry below, which touched no line of `series_level.{ml,mli}`.

- [x] **`Series_level` wired into `Build_runner`, report-only and default-off**
  (feat/series-level-build-runner, PR #2875). The detector had shipped tested
  and called by nothing; this is the wiring half only — no change to
  `series_level.{ml,mli}`, no detection logic, no threshold.
  - **`Level_pass`**
    (`trading/analysis/scripts/build_snapshots/level_pass.{ml,mli}`, ~55 lines)
    owns the two *impure* halves of arming a pure module: the `Core.Command`
    flag block and the sidecar write. The **contract** is `-detect-splices`'
    (#2649) — default-off master switch, a CSV named after the pass,
    report-only. The **module boundary** is `Twin_pass`' rather than an inline
    block in `build_scenario_snapshots.ml`, because unlike the splice scan (a
    pre-pass in that one CLI shell) this pass runs *inside* `Build_runner.build`
    beside `Series_tail`, so both builders must surface one shared `params`
    instead of two drifting copies. It also keeps 56 lines out of
    `build_runner.ml`, which grows 729 → 771 all the same (+42, ~25 of them the
    comments explaining the classification basis and the no-op contract). That
    path is not covered by `linter_file_length.sh` (`*/lib/*.ml` only), so
    nothing was gated on the number; `build` did trip the **fn-length** linter at
    52 lines and was fixed by extracting a `_hygiene_opts` constructor, not by
    bumping a limit or adding a marker (`code-health-discipline.md`).
  - `Build_runner.build` gains `?level_config`; `hygiene_opts` gains
    `level_config`; `built` gains `level : Series_level.finding option`. Each
    symbol's **stored** series — after the splice cut and after the tail rule —
    is classified, and the rows land in `<output_dir>/series_level.csv`. The
    basis is deliberate: the residual class is defined against what actually
    lands in the `.snap` (a seam outside the window presents, inside it, as a
    uniformly mis-scaled stored series), so classifying the raw pre-cut bars
    would instead re-find defects the shape rules already removed.
  - CLI on **both** builders: `-detect-series-level`,
    `-series-level-median-max R`, `-series-level-min-bars N`. Every
    `Series_level.Config` field is reachable from the command line, so
    recalibrating the ceiling against a real warehouse needs no rebuild.
  - **Unarmed is bit-identical**: `classify` reads no bar and `write_report`
    writes no file, so an un-armed build leaves no trace in its output
    directory. **Armed is still bit-identical** — the pass has no action type,
    so nothing is dropped, cut or truncated whatever it finds. No config default
    changed, so no paired golden run was required
    (`config-default-blast-radius.md` B1).
  - Verify: `dune runtest analysis/scripts/build_snapshots/` — 12 cases in
    `test/test_build_runner_level.ml`: flag OFF ⇒ no sidecar; armed-vs-unarmed
    manifest entries equal **as whole records** (report-only, pinned in both
    directions); flag ON ⇒ a file with the exact `csv_header`; the
    `whole_window` and `mixed_scale` rows as literal CSV lines; an ordinary
    series yielding no row; an armed pass with nothing to report writing the
    **header alone**; both tuning knobs shown live; and the classification
    basis pinned on both edits — a splice-cut symbol yields no row while the
    same uncut fixture does, and a stray-dropped symbol's row carries the
    stored 21 bars rather than the 22 that were read.
  - Mutation-verified: `classify` handed `enabled = false` reddens the three
    detector-reached cases (and dropping the `level_config` read outright fails
    to compile on warning 69, which is its own proof the field is live);
    removing `write_report`'s config gate reddens the flag-OFF case; clearing
    `active_through` for flagged symbols in `_entry_with_derived_marker`
    reddens the no-op case; and hoisting `_classify_level` above `_cut_splice` /
    `_clean_tail` reddens the two ordering cases. The last two were **green**
    against the pre-rework suite — the identity check projected entries to
    `(symbol, payload_md5)` and no fixture carried a delisting marker or was
    touched by either edit, so neither claim was pinned (QC rework iteration 1,
    CP1/CP3).

## Follow-ups

- Quarantine MEL from the 2000 vintage, or re-fetch and validate the series
  (issue #2732 ask 1) — V18 makes the artifact detectable, it does not remove
  it or restate any affected number. Ask 3 (re-run the item-3 cells after the
  #2730 twin dedupe) likewise still open.
- Run V18 over the canonical 26y record as first acceptance: expect MEL to
  reproduce, and review whatever else the level rule surfaces to calibrate
  whether $10,000 is the right ceiling for a broad universe.
- **Arm `-detect-series-level` on the next warehouse rebuild and read
  `series_level.csv`.** The wiring landed in PR #2875 (see Fixes above), so this
  follow-up is now purely operational: pass the flag to `build_snapshots.exe` /
  `build_scenario_snapshots.exe` on the next vintage build, and review the
  sidecar. Nothing in the repo arms it, by design. Expect `Mixed_scale` rows
  (sub-class (ii): PEGX / CGE / TNT / HTV, whose prefix cut the 250-bar
  short-tail guard correctly refuses) and possibly **zero** `Whole_window` rows
  — see the next item for why that is the expected result rather than a defect.
- Decide, off that first armed report, whether a `Whole_window` row warrants a
  **drop** action. **Expect the report to be able to come back empty of
  `Whole_window` rows** — the seven seam dates evidencing sub-class (i) are all
  *in*-window for the three committed 2026-ending vintages, so that sub-class is
  code-level certain but has no present-day instance; an empty report is the
  expected result, not broken wiring. The instance-verified rows are sub-class
  (ii)'s, and those land in `Mixed_scale`. That is the gap no existing module
  can express — `Series_tail
  .Action` has no drop at all, and `Series_splice.Action.Dropped` needs 20+
  splice findings — and it is what would finally cover PEGX / CGE / TNT / HTV,
  whose prefix cut the 250-bar short-tail guard correctly refuses but which are
  then stored artefact and all. Any such action must stay opt-in: the rule
  knowingly flags BRK.A, and an automatic drop there deletes a real company.
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

## Last updated: 2026-09-20

## Interface stable

NO
