# Track: post-run-validation

## Status

READY_FOR_REVIEW

## Owner

feat-backtest

## Summary

A read-only **post-run trade validator** (v1, report-only) that consumes a
completed scenario run's artifacts (`trades.csv`, `trade_audit.sexp`,
`open_positions.csv`) plus the per-symbol bar store, checks every trade against
11 declared invariants / expectations (V1-V11), and emits a validation report
(`<out>.sexp` + human `<out>.md`).

Derived from the 2026-07-12 visual trade audit
(`dev/notes/visual-trade-audit-2026-07-12.md`), which found the W12 bear-rally
loss class (COO/ANF/ASTE/AIR/TFX/OLED/STRA/BF-B) and several export defects.
Design: `dev/plans/post-run-validation-2026-07-12.md`. User directive: "we
should have some kind of post-backtest validation to verify the invariants /
expectations so we never make these kinds of trades again."

## Surface

- `trading/trading/backtest/validation/lib/post_run_validator.{ml,mli}` — 11
  pure check functions over parsed rows + a `run` orchestrator.
- `trading/trading/backtest/validation/bin/post_run_validator_cli.ml` — CLI
  (`-run-dir -data-dir [-config] -out`).
- `trading/trading/backtest/validation/test/test_post_run_validator.ml` — unit
  tests for V1, V2, V5, V6, V9, V10, V11, audit-join + severity/validate wiring
  (22 tests).

## Checks (V1-V11)

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

v1 is **report-only** (exit code always 0). Severity default: V1-V7 INVARIANT,
V8-V11 EXPECTATION; every check's severity is config-overridable
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

## Follow-ups

- Wire `scenario_runner --validate` post-step (out of scope for v1 per plan).
- Add a golden-run expected band (all invariants zero) once gates are armed.
- Live-side reuse: run the same checks against a weekly picks snapshot before
  the report is trusted (deployment checklist item).
- V3/V4/V7 real-artifact coverage: unit-tested checks are V1/V2/V5/V6/V9/V10/V11;
  the bar-dependent V3/V4/V7 are covered structurally but want a golden-run
  integration test.

## Last updated: 2026-07-12

## Interface stable

NO
