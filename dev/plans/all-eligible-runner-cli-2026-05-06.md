# All-eligible runner CLI (issue #870 PR-2)

## Context

PR #899 (already merged) shipped `Backtest_all_eligible.All_eligible.grade` —
the pure projection that, given a list of `Optimal_types.scored_candidate`,
produces per-trade fixed-dollar `trade_record`s + an `aggregate`. PR #899 explicitly
deferred the CLI exe + on-disk emission.

This PR (PR-2) adds the CLI exe so the diagnostic can run end-to-end against a
real backtest scenario file.

## Approach

Mirror the shape of `optimal_strategy.exe` (`trading/trading/backtest/optimal/bin/`):

- A small `lib/all_eligible_runner.{ml,mli}` that owns scenario loading,
  snapshot construction, scan + score orchestration, the `grade` call, and
  artefact emission.
- A thin `bin/all_eligible_runner.ml` (~30 LOC) that parses argv and
  delegates to `All_eligible_runner.run`.
- Tests under `bin/test/` exercise the runner end-to-end against a synthetic
  CSV-bar fixture (same shape as `test_optimal_strategy_runner.ml`'s
  `_stage_fixture`).

### CLI

```
all_eligible_runner.exe \
  --scenario <path-to-scenario-sexp> \
  [--out-dir <path>] \
  [--entry-dollars <float>] \
  [--return-buckets <comma-separated-floats>] \
  [--config-overrides <sexp-list>]
```

Defaults:
- `--out-dir` → `dev/all_eligible/<scenario.name>/<UTC-ISO-timestamp>/` (created if absent).
- `--entry-dollars` → `10_000.0` (matches `All_eligible.default_config`).
- `--return-buckets` → `-0.5,-0.2,0.0,0.2,0.5,1.0` (matches `All_eligible.default_config`).
- `--config-overrides` → empty list (scenario file's `config_overrides` are still applied).

### Output emission

Three files in `out_dir/`:

1. `trades.csv` — one row per `trade_record`, header included. Schema:
   `signal_date,symbol,side,entry_price,exit_date,exit_reason,return_pct,hold_days,entry_dollars,shares,pnl_dollars,cascade_score,passes_macro`.
2. `summary.md` — Markdown table of the `aggregate`, plus scenario / period
   header and the bucket histogram.
3. `config.sexp` — the resolved `All_eligible.config` used (sexp_of_config),
   for reproducibility.

### Reuse vs duplication

The optimal-strategy runner has internal helpers `_build_world` and
`_scan_and_score` that we'd love to call directly. They're private (`_` prefix),
so the all-eligible runner inlines small versions of:

- snapshot construction (`Csv_snapshot_builder.build` + `Daily_panels.create`
  + `Snapshot_callbacks.of_daily_panels`)
- Friday calendar (`_friday_on_or_before` + `_fridays_in_range`)
- per-Friday `Stock_analysis.analyze` over the universe
- `Stage_transition_scanner.scan_week` per Friday
- forward weekly-outlook table built once
- `Outcome_scorer.score` per candidate

This is ~150 LOC of orchestration duplication. A follow-up could extract these
into a shared `Backtest_optimal.Scan_and_score` module; deferred to keep this
PR focused.

## Files to change

New:
- `trading/trading/backtest/all_eligible/lib/all_eligible_runner.{ml,mli}`
- `trading/trading/backtest/all_eligible/lib/dune` — extend libraries list
- `trading/trading/backtest/all_eligible/bin/dune`
- `trading/trading/backtest/all_eligible/bin/all_eligible_runner.ml` — thin CLI
- `trading/trading/backtest/all_eligible/bin/test/dune`
- `trading/trading/backtest/all_eligible/bin/test/test_all_eligible_runner.ml`

No modifications to existing modules (PR #899's `all_eligible.{ml,mli}` is
untouched).

## Tests

Smoke / integration tests in `bin/test/test_all_eligible_runner.ml`:

1. `test_run_emits_three_artefacts` — synthetic 3-symbol fixture, call
   `All_eligible_runner.run`, assert all three files exist in out_dir.
2. `test_summary_md_contains_aggregate_fields` — same fixture, parse
   `summary.md` and pin presence of "trade_count", "win_rate_pct", "Bucket"
   substrings.
3. `test_trades_csv_has_header_and_one_row_per_trade` — count CSV lines;
   header + N rows where N matches the scored-candidate count.
4. `test_config_sexp_round_trips` — read back `config.sexp`, assert it parses
   as `All_eligible.config_of_sexp`.

## Acceptance criteria

- `dune build && dune runtest` green; `dune build @fmt` clean.
- Bin exe produces `trades.csv`, `summary.md`, `config.sexp` in the expected
  out_dir.
- LOC: ≤ 500 source (lib + bin), tests excluded.
- One concern (this PR-2). PR #899's lib is untouched.
