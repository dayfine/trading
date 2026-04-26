# Status: cleanup

## Last updated: 2026-04-26

## Status
IN_PROGRESS

## Interface stable
NO

Cleanup track has no public interface — it absorbs small mechanical fix-ups surfaced by `health-scanner` (deep + fast scans) so feature agents stay focused on feature work. The "interface" here is the `dev/status/cleanup.md` Backlog schema, which is maintained by the orchestrator and consumed by `code-health`.

## Ownership
`code-health` agent — see `.claude/agents/code-health.md`. Dispatched by `lead-orchestrator` Step 2e on health-scan findings, one finding per dispatch, ≤200 LOC, no behavior change.

## Backlog

Orchestrator populates this from `dev/health/<date>-{fast,deep}.md`. Items here are eligible for next dispatch.

- [ ] nesting: trading/analysis/data/storage/csv/lib/csv_storage.ml — `_stream_in_range_prices` (line 180) avg=3.61 max=9 from PR #543 H7 stream-parse refactor (source: 2026-04-26-fast.md)

## Completed

- [x] fn_length / file_length: weinstein_strategy.ml — added @large-module annotation; file length linter now passes. (source: 2026-04-19-fast.md, PR #453, 2026-04-19)

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
