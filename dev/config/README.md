# dev/config

Runtime configuration files read by the lead-orchestrator and related
harness scripts. Keep these files small, versioned, and hand-editable —
they are the knobs a human tweaks between runs.

## merge-policy.json

Controls the orchestrator's non-blocking maintenance scheduling and
(eventually) automatic merging. Read by `lead-orchestrator` Step 2b.

| Key | Default | Meaning |
| --- | --- | --- |
| `followup_threshold` | `10` | If the total open-followup count across all feature status files exceeds this, the orchestrator is eligible to replace one feature slot with a maintenance pass. |
| `maintenance_cycle_ratio` | `3` | Even once the threshold is exceeded, a maintenance pass runs at most every Nth run (default every 3rd). |
| `auto_merge_enabled` | `false` | Reserved for T4-B. When `true`, clean-pass features are auto-merged to `main`. Leave `false` until the auto-merge path has a human-reviewed dry-run track record. |

The defaults here mirror the inline defaults documented in
`.claude/agents/lead-orchestrator.md` Step 2b — this file makes them
visible and tweakable without editing the agent definition.
