# Status: cost-tracking

## Last updated: 2026-04-20

## Status
IN_PROGRESS

## Interface stable
NO

## Ownership
harness-maintainer

## What this track owns

Cost measurement and reporting infrastructure for the GHA orchestrator runs.

### Components

- `dev/budget/<date>-run<N>.json` — per-run structured budget records
- `dev/config/merge-policy.json` `model_prices` block — canonical pricing table
- `.github/workflows/orchestrator.yml` "Capture run cost" step — writes budget records post-run
- `dev/lib/budget_rollup.sh` — weekly/on-demand rollup tool
- `trading/devtools/checks/budget_rollup_check.sh` — smoke test (wired into dune runtest)
- `lead-orchestrator.md` Step 7 `## Budget` — emits measured data when budget record exists

### What is measured vs estimated

| Signal | Measured? | Source |
|--------|-----------|--------|
| Total run cost (USD) | YES | `total_cost_usd` in `claude-code-action` execution_file |
| Per-subagent cost | NO | Not available from action (see Limitations) |
| Token counts (input/output/cache) | NO | Not available from action |
| Cache hit rate | NO | Not available from action |
| Model used per subagent | NO | Estimated from agent definition |

### Pricing table

Source: `dev/config/merge-policy.json` `model_prices` block.
Verified from `https://claude.com/pricing` on 2026-04-20.

**Note:** Prices differ from the Jan 2026 estimates in the task spec because Anthropic
has updated pricing. Claude Opus 4.7 is $5/$25 (not $15/$75), Sonnet 4.6 is $3/$15
(unchanged), Haiku 4.5 is $1/$5 (unchanged). The current published prices are used.

## Fallback branch

**1b** (middle case): The action logs `total_cost_usd` to the execution file
(`claude-execution-output.json`), which is exposed via the `execution_file` output
variable of `claude-code-action@v1`. We parse this file in a post-action GHA step.

### Why not 1a (per-subagent from action output)

`claude-code-action@v1` runs the orchestrator as a single Claude Code process. The
orchestrator internally spawns subagents using the `Agent` tool. From the action's
perspective, there is one invocation — no per-subagent breakdown in the execution file.
The `SDKResultMessage.total_cost_usd` covers the entire run.

### Why not 1c (nothing available)

The execution file does contain `total_cost_usd` in the result message. This is
meaningful: the orchestrator and all its subagents share one cost figure. We can
track run-to-run cost trends and see if PRs #481/#482 moved the needle on total cost.

## Known gaps

1. **Per-subagent breakdown**: Only available if the orchestrator is refactored to
   log per-agent costs from within its own `## Budget` section and commit that to
   the budget JSON. The orchestrator already estimates costs in Step 3.75; it could
   write measured costs from the Agent tool's return values if the SDK surfaces them.
   Filed as follow-up: orchestrator could write per-track costs to budget file directly.

2. **Token counts not captured**: `total_cost_usd` is available but raw token counts
   (input, output, cache_read, cache_creation) are not exposed by the action. If the
   action is updated to surface these in the execution file, update the GHA step parser.

3. **Orchestrator's own overhead vs subagent cost**: The single `total_cost_usd`
   conflates orchestrator reasoning (reading status files, writing summaries) with
   subagent work. No way to separate without per-agent SDK instrumentation.

4. **OTEL path (future)**: The action supports `CLAUDE_CODE_ENABLE_TELEMETRY` +
   `OTEL_EXPORTER_OTLP_*` env vars. A future improvement could ship telemetry to an
   OTLP collector for per-turn granularity. Out of scope for this PR.

## Follow-up / Known Improvements

- Orchestrator self-reports measured per-track costs in Step 7 by reading the Agent
  tool's return value (if SDK exposes usage). Then commits that data to budget JSON
  before Step 8 pushes the branch. This gives per-subagent breakdown without the
  action needing to change.
- Consider upstreaming a feature request to `anthropics/claude-code-action` to expose
  per-subagent usage in the execution file or a separate structured output.

## Next Steps

1. Verify GHA "Capture run cost" step produces valid JSON on next orchestrator run
2. Run `dev/lib/budget_rollup.sh` after several runs to see cost trend
3. Compare costs before/after PRs #481 (saturated-queue fast-exit) and #482 (qc-structural → Haiku)
