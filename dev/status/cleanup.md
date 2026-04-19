# Status: cleanup

## Last updated: 2026-04-19

## Status
IN_PROGRESS

## Interface stable
NO

Cleanup track has no public interface — it absorbs small mechanical fix-ups surfaced by `health-scanner` (deep + fast scans) so feature agents stay focused on feature work. The "interface" here is the `dev/status/cleanup.md` Backlog schema, which is maintained by the orchestrator and consumed by `code-health`.

## Ownership
`code-health` agent — see `.claude/agents/code-health.md`. Dispatched by `lead-orchestrator` Step 2e on health-scan findings, one finding per dispatch, ≤200 LOC, no behavior change.

## Backlog

Orchestrator populates this from `dev/health/<date>-{fast,deep}.md`. Items here are eligible for next dispatch.

- [ ] fn_length / file_length: trading/trading/weinstein/strategy/lib/weinstein_strategy.ml — module 320 lines, soft limit 300. Either annotate with `(* @large-module: <reason> *)` at the top (acceptable if the module is a cohesive whole and no obvious split exists) or extract a sub-module (e.g., stage-transition helpers or risk helpers) to drop back below 300. (source: 2026-04-19-fast.md)

## Completed

- (none yet)

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
