# Status: decision-audit

## Last updated: 2026-07-01

## Status
MERGED

## Interface stable
YES

Per-screen faithfulness decision-audit (spec #8,
`dev/plans/per-screen-decision-audit-2026-06-30.md`). Additive, default-off
(read-only lens), no engine/strategy behaviour change. Consumes the
`trade-audit` track's `trade_audit.sexp`.

## Goal

Surface the near-miss data already captured in `trade_audit.sexp` as a
per-screen **faithfulness** audit — comparing each weekly screen's **funded**
entries against the **cash-rejected near-misses** on the *captured decision-time
features* (score, grade, stage, weeks_advancing, rs_value, volume_ratio,
sector). Not an outcome grader: the question is capture/use-completeness ("does
any signal we record separate funded from near-miss, and are we funding on it?"),
not "did the picks make money" (which is WAI-poor).

## Completed

- [x] **Phase 0 — enrich `alternative_candidate`** (this PR, commit 1).
  Added `stage / weeks_advancing / rs_value / volume_ratio / sector_name /
  score_components` to `Backtest.Trade_audit.alternative_candidate` so
  near-misses carry the same decision-time features the funded `entry_decision`
  records. Sourced in `trade_audit_recorder._alternative_of_event` from each
  near-miss's own `Screener.scored_candidate` (analysis.stage / .rs / .volume /
  sector). `score_components` is `[]` until the screener exposes per-component
  contributions (same ceiling the funded `cascade_score_components` has today).
  Additive + default-populated; existing readers unchanged. Round-trip sexp test
  extended. Verify: `dune runtest trading/backtest/test` (test_trade_audit, 19
  tests).
- [x] **Phase 1 — `decision_audit` lib + bin + tests** (this PR, commit 2).
  New `trading/trading/backtest/decision_audit/{lib,bin,test}/`.
  - `Screen_record.of_audit_records` groups entry decisions by screen date,
    projects funded/near-miss, dedups near-misses by symbol (score-desc),
    computes summary (min funded score, max near-miss score, inversion flag).
  - `Report.feature_stats` + `to_markdown` render the faithfulness roll-up
    (funded-vs-near-miss means per feature + skip-reason breakdown) plus one
    section per screen date.
  - `decision_audit_bin` CLI: `--audit <trade_audit.sexp> [--out <md>]`.
  Verify: `dune runtest trading/backtest/decision_audit` (10 tests: 6
  screen_record + 4 report). Smoke: `dune exec
  trading/backtest/decision_audit/bin/decision_audit_bin.exe -- --audit
  <trade_audit.sexp>`.
- [x] **Phase 2 — forward-return counterfactual** (`feat/decision-audit-phase2`).
  New `decision_audit/lib/counterfactual.{ml,mli}` — the one place outcome
  enters: `Counterfactual.compute records ~bar_reader ~horizon_weeks` produces
  one `candidate_forward` per candidate (funded ∪ near-miss, dedup toward
  funded). Base price = close of the first bar at/after the screen date;
  `forward_return_pct` reuses `Decision_grading.Post_exit.post_exit_metrics`'s
  `continuation_pct` (signed, side-adjusted) — not re-implemented. `None` when
  the symbol is absent from the warehouse / has no bar at/after the screen. The
  pure arithmetic is unit-tested against an in-memory `Bar_reader` (long, short
  sign-flip, missing symbol, all-bars-before-screen, funded/near-miss partition,
  dup-symbol dedup). `Report.counterfactual_to_markdown` renders the headline
  funded-vs-near-miss forward-return **mean + median + n** (per
  `mechanism-validation-rigor.md`) plus near-miss split by `skip_reason`
  (Insufficient_cash first), labelled as the "usable signal left on the table"
  test (null/overlapping = faithful). `decision_audit_bin` gains
  `--snapshot-dir <warehouse>` (builds a snapshot-backed `Bar_reader` exactly as
  `decision_grading_bin`) + `--horizon-weeks <N>` (default 12); absent
  `--snapshot-dir`, behaves as Phase-1 only. Also added `side` to
  `Screen_record.near_miss` (sourced from `alternative_candidate.side`) so short
  near-misses sign-adjust. Verify: `dune runtest
  trading/backtest/decision_audit` (20 tests: 6 screen_record + 8 report + 6
  counterfactual). Smoke: `dune exec
  trading/backtest/decision_audit/bin/decision_audit_bin.exe -- --audit
  <trade_audit.sexp> --snapshot-dir <warehouse> --horizon-weeks 12`.
- [x] **Weekly-snapshot adapter — live picks → the faithfulness lens**
  (`feat/decision-audit-weekly`). New
  `decision_audit/lib/weekly_adapter.{ml,mli}`:
  `Weekly_adapter.of_weekly_snapshots snaps ~displayed_k` maps each per-Friday
  `Weinstein_snapshot.Weekly_snapshot.t` to one `Screen_record.t` so the SAME
  Phase-1 report + Phase-2 counterfactual run on live weekly picks, not just a
  backtest `trade_audit.sexp`. The displayed cut synthesizes the funded/near-miss
  split a live snapshot lacks: `funded` = the first `displayed_k` `long_candidates`
  (score-desc); `near_misses` = the remaining longs (side `Long`) ∪ all
  `short_candidates` (side `Short`), all tagged `Top_n_cutoff` (the live analog of
  the backtest cash line). `summary` reuses the newly-exposed
  `Screen_record.summary_of` (no duplication). Documented ceilings: stage defaults
  to `Stage2 {weeks_advancing=0; late=false}` for longs / `Stage4 {weeks_declining=0}`
  for shorts (snapshot carries no stage; faithful by screener construction), and
  `weeks_advancing` / `volume_ratio` are `None` (not in the snapshot schema — RS +
  score + grade + sector are what this enables). Grade parsed from the displayed
  label ("A+"/"A"/…) by an exhaustive `_grade_of_string` that raises
  `Invalid_argument` on an unknown label (never silently defaults). `decision_audit_bin`
  gains `--weekly-picks-dir <dir>` (loads every `*.sexp` via
  `Snapshot_reader.read_from_file`, sorts by date) + `--displayed-k <N>` (default 3),
  mutually exclusive with `--audit`; `--audit` mode unchanged. Verify: `dune runtest
  trading/backtest/decision_audit` (25 tests: 6 screen_record + 8 report + 6
  counterfactual + 5 weekly_adapter). Smoke: `dune exec
  trading/backtest/decision_audit/bin/decision_audit_bin.exe -- --weekly-picks-dir
  dev/weekly-picks/<version> --displayed-k 3`.

## Follow-ups

- **score_components** — populate once the screener splits its additive score
  into per-component contributions (would lift the current ceiling for both the
  funded path and near-misses).
