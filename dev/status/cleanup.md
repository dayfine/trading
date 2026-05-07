# Status: cleanup

## Last updated: 2026-05-07

## Status
IN_PROGRESS

## Interface stable
NO

Cleanup track has no public interface — it absorbs small mechanical fix-ups surfaced by `health-scanner` (deep + fast scans) so feature agents stay focused on feature work. The "interface" here is the `dev/status/cleanup.md` Backlog schema, which is maintained by the orchestrator and consumed by `code-health`.

## Ownership
`code-health` agent — see `.claude/agents/code-health.md`. Dispatched by `lead-orchestrator` Step 2e on health-scan findings, one finding per dispatch, ≤200 LOC, no behavior change.

## Backlog

- [x] fn_length + magic_numbers: trading/analysis/weinstein/snapshot_runtime/lib/snapshot_bar_views.ml — condensed comments −15 lines (297); restructured to avoid bare literals on mid-comment lines. PR #924 (2026-05-07)
Orchestrator populates this from `dev/health/<date>-{fast,deep}.md`. Items here are eligible for next dispatch.

## Completed

- [x] fn_length + file_length: trading/trading/backtest/lib/runner.ml — extracted `Runner_metrics` module + `_filter_steps`/`_extract_filtered_logs` helpers; runner.ml 528→468 lines, `run_backtest` 83→49 lines. Branch cleanup/runner-fn-length (2026-05-07)
- [x] fn_length: trading/trading/backtest/optimal/lib/optimal_strategy_runner.ml — extracted 8 helpers to Optimal_friday_helpers; 413→270 lines (branch cleanup/optimal-strategy-runner, 2026-05-07)
- [x] file_length: trading/trading/backtest/optimal/lib/optimal_strategy_report.ml — extracted divergence + missed-trades sections to Optimal_strategy_report_sections; 488→281 lines (source: dispatch 2026-05-07, PR #928)
- [x] file_length: trading/trading/backtest/lib/panel_runner.ml — extracted step-loop helpers to Panel_step_loop module; 309→237 lines (source: dispatch 2026-05-07, branch cleanup/file-length-panel-runner)
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
