# Status: cleanup

## Last updated: 2026-05-08

## Status
IN_PROGRESS

## Interface stable
NO

Cleanup track has no public interface — it absorbs small mechanical fix-ups surfaced by `health-scanner` (deep + fast scans) so feature agents stay focused on feature work. The "interface" here is the `dev/status/cleanup.md` Backlog schema, which is maintained by the orchestrator and consumed by `code-health`.

## Ownership
`code-health` agent — see `.claude/agents/code-health.md`. Dispatched by `lead-orchestrator` Step 2e on health-scan findings, one finding per dispatch, ≤200 LOC, no behavior change.

## Backlog

- [~] nesting: trading/trading/simulation/lib/split_handler.ml — apply_to_position avg 4.31 max 6; apply_to_positions avg 3.43 max 6; file avg 3.12 (source: dispatch 2026-05-08)
- [~] nesting: trading/analysis/data/sources/wiki_sp500/lib/ticker_aliases.ml — file avg 2.63 (limit 2.5); deep record literals in all list (source: dispatch 2026-05-07)
- [~] nesting: trading/trading/weinstein/strategy/lib/entry_audit_capture.ml — emit_entries avg 5.41 max 9; classify_candidate avg 5.30 max 11; file avg 2.76 (source: dispatch 2026-05-07)
- [x] fn_length + magic_numbers: trading/analysis/weinstein/snapshot_runtime/lib/snapshot_bar_views.ml — condensed comments −15 lines (297); restructured to avoid bare literals on mid-comment lines. PR #924 (2026-05-07)
Orchestrator populates this from `dev/health/<date>-{fast,deep}.md`. Items here are eligible for next dispatch.

## Completed

- [x] nesting: trading/trading/weinstein/snapshot/lib/snapshot_reader.ml — extracted _parse_sexp + _deserialize_snapshot helpers; hoisted msg in _check_schema_version; parse/file avg violations gone (branch cleanup/nesting-snapshot-reader, 2026-05-08)
- [x] nesting: trading/trading/weinstein/strategy/lib/exit_audit_capture.ml — extracted _pct_distance_from_callbacks, _make_exit_event, _handle_trigger_exit helpers; nesting linter now passes. (branch cleanup/nesting-exit-audit-capture, 2026-05-07)
- [x] fn_length + file_length: trading/trading/backtest/lib/runner.ml — extracted `Runner_metrics` module + `_filter_steps`/`_extract_filtered_logs` helpers; runner.ml 528→468 lines, `run_backtest` 83→49 lines. Branch cleanup/runner-fn-length (2026-05-07)
- [x] fn_length: trading/trading/backtest/optimal/lib/optimal_strategy_runner.ml — extracted 8 helpers to Optimal_friday_helpers; 413→270 lines (branch cleanup/optimal-strategy-runner, 2026-05-07)
- [x] file_length: trading/trading/backtest/optimal/lib/optimal_strategy_report.ml — extracted divergence + missed-trades sections to Optimal_strategy_report_sections; 488→281 lines (source: dispatch 2026-05-07, PR #928)
- [x] file_length: trading/trading/backtest/lib/panel_runner.ml — extracted step-loop helpers to Panel_step_loop module; 309→237 lines (source: dispatch 2026-05-07, branch cleanup/file-length-panel-runner)
- [x] file_length: trading/trading/backtest/lib/result_writer.ml — extracted trades-CSV cluster to Trades_writer module; 372→245 lines (source: dispatch 2026-05-07, PR #929)
- [x] fn_length + file_length: trading/trading/weinstein/strategy/lib/entry_audit_capture.ml — extracted entry construction + debug trace helpers to entry_audit_helpers.ml; 383→272 lines; make_entry_transition 54→31 lines (PR #930, 2026-05-07)
- [x] nesting: trading/analysis/data/storage/csv/lib/csv_storage.ml — extracted `_parse_and_accumulate` and `_read_next_line` helpers; nesting linter now passes (835 fns, all OK). (source: 2026-04-26-fast.md, PR #578 merged 2026-04-26T16:04Z)
- [x] fn_length / file_length: weinstein_strategy.ml — added @large-module annotation; file length linter now passes. (source: 2026-04-19-fast.md, PR #453, 2026-04-19)
- [x] file_length: trading/analysis/weinstein/screener/lib/screener.ml — extracted sector_rating/scoring_weights/grade_thresholds types + signal helpers + price helpers to Screener_scoring; 708→485 lines (under 500 hard limit). (source: dispatch 2026-05-07, branch cleanup/screener-large)

## Out of scope

- Behavior changes — escalate to the relevant feat-agent.
- Linter rule changes — `harness-maintainer` owns `devtools/checks/`.
- Multi-file refactors crossing module boundaries — feat-agent.

## How findings get here

`lead-orchestrator` Step 2e parses the most recent `dev/health/<date>-deep.md` and `<date>-fast.md`, picks `[medium]` or `[high]` findings (skips `[info]`), and appends one Backlog entry per finding it doesn't already see. The entry shape is:

```
- [ ] <finding type>: <file path> — <one-line context> (source: <date>-deep.md)
```

Subsequent runs may dispatch `code-health` to work the top item; agent flips to `[~]` on start, `[x]` on completion.
