# dev/config

Runtime configuration files read by the lead-orchestrator and related
harness scripts. Keep these files small, versioned, and hand-editable —
they are the knobs a human tweaks between runs.

## merge-policy.json

Controls the orchestrator's non-blocking maintenance scheduling and
(eventually) automatic merging. Read by `lead-orchestrator` Step 2b.

| Key | Default | Meaning |
| --- | --- | --- |
| `followup_threshold_per_file` | `4` | Nonnegative integer. If any status file exceeds this actionable open-item count, the orchestrator is eligible for a maintenance pass. Count `- [ ]` throughout each file, excluding Tier 2/Tier 4 roadmap sections and fenced templates. |
| `maintenance_cycle_ratio` | `3` | Even once the threshold is exceeded, a maintenance pass runs at most every Nth run (default every 3rd). |
| `auto_merge_enabled` | `false` | Reserved for T4-B. When `true`, clean-pass features are auto-merged to `main`. Leave `false` until the auto-merge path has a human-reviewed dry-run track record. |

The defaults here mirror the inline defaults documented in
`.claude/agents/lead-orchestrator.md` Step 2b — this file makes them
visible and tweakable without editing the agent definition.

The per-file threshold replaces the old repo-wide threshold of 10 (#2742).
Four items per track is ordinary; adding more lightly loaded tracks should
not trigger maintenance. Deep-scan Check 5 reads this policy and reports the
maximum per-file count and number of overloaded files, alongside repo-wide
totals. A missing file/key uses 4; an invalid configured value fails the check.
