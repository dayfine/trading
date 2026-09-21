---
name: project_perf_tiers_timed_all_eligible_diagnostic
description: "⭐ 09-21 weekly perf review: every perf tier script omitted --no-emit-all-eligible, so the opt-out all-eligible diagnostic ran inside every tier cell (and inside the measured wall since #2616). Tier-3 15y cells read 4,738 s / 716 MB vs 364 s / 550 MB on the daily golden path (same binary, same GC params) — ~92 % of the figure was diagnostic; 5y cells 10× the same way. The 3,600 s wall band FAILed on it alone for 3 weeks with no readable cause (no artefacts uploaded). Fixed in #2894; tickets #2895 (FAIL rows) / #2896 (PIT-warehouse smoke cell)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 1831a3c4-b96e-4b7e-b4df-9bf0d2c0da12
  modified: 2026-09-21T19:28:13.805Z
---

**Finding (2026-09-21, first real pass of `.claude/rules/perf-review-weekly.md`):** `dev/scripts/perf_tier{1,2,3,4}_*.sh`
and `run_tier4_release_gate.sh` never passed `--no-emit-all-eligible`; `golden_sp500_postsubmit.sh` (since #2601's rework
08-31), `promote_config.sh` and every verdict chain do. `emit_all_eligible` defaults to `true` in `scenario_runner`, and
#2616 (09-01) moved the `wall_seconds` timer to span the post-steps, so from 09-01 the tiers timed backtest + diagnostic.

| cell | tier-3 weekly | 15y / 5y golden (flag on) |
|---|---:|---:|
| sp500-2010-2026 | 4,738 s / 717 MB | 364 s / 550 MB |
| sp500-2019-2023 | 923 s / 387 MB | 88 s / 310 MB |

The 15y golden's own history shows the switch: 5,125 s / 715 MB on 08-29 → 402 s / 547 MB on 09-01.

**Why it stayed hidden:** `perf-weekly.yml` runs with `continue-on-error: true` and uploaded no cell logs, so a FAIL row
had no cause to read; and nobody compared the tier table against the golden table for the same cell.

**How to apply:** (1) when a cell's wall looks wrong, find the *same cell in another workflow* before reading the
binary — invocation flags, not code, were the whole delta; (2) the perf tables' baseline drops ~10× after #2894 — compare
post-09-21 rows to the golden-path numbers above, never to pre-09-21 tier rows; (3) any new runner-side diagnostic must
be opt-in on the perf tiers, or the tier measures the diagnostic. Related: [[feedback_weekly_perf_review_budget]],
[[project_snapshot_cache_handle_cap_thrash]].
