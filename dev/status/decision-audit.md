# Status: decision-audit

## Last updated: 2026-07-01

## Status
READY_FOR_REVIEW

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

## Follow-ups

- **Phase 2 (stretch)** — forward-return counterfactual on the cash-rejected
  names (reuse `decision_grading/post_exit`), the one place outcome enters, to
  test whether *usable captured signal* is left on the table. Out of scope here.
- **score_components** — populate once the screener splits its additive score
  into per-component contributions (would lift the current ceiling for both the
  funded path and near-misses).
