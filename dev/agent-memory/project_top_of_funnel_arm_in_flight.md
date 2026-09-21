---
name: project_top_of_funnel_arm_in_flight
description: "⭐ 09-21 IN FLIGHT: top-N capacity arm t1-topn-40 (screening_config.max_buy_candidates 20→40, 3 salts) + d0-funnel-diag (null s0 with --emit-candidates, trades md5 tripwire c1352be6…) on the PIT band; pre-registered #2897, chain lane A launched 13:25 PT on sweep-funnel @ ad5a9e04e; rule = realised AND Calmar at ≥2/3 salts; read by entry-year on symbol|entry_date, scoped to cap-bound weeks. candidates.sexp (~500 MB/cell) never committed — commit the derived decomposition."
metadata: 
  node_type: memory
  type: project
  originSessionId: 1831a3c4-b96e-4b7e-b4df-9bf0d2c0da12
  modified: 2026-09-21T20:26:32.959Z
---

**What is running (2026-09-21 13:25 PT, `dev/experiments/top-of-funnel-2026-09-21/`):** lane A =
`d0-funnel-diag:0:emit → t1-topn-40:0 → :1 → :2`, ~4 h/cell on the #2882 knob build (cap 12,000), guard 60,000 s.
Chain log `/tmp/funnel-run/chain-A.log`; artifacts `/tmp/sweeps/top-of-funnel/`; pinned worktree
`.claude/worktrees/sweep-funnel` @ `ad5a9e04e` (remove after archiving). Script/specs staged under `/tmp/funnel-run/`
(outside VCS), so parent-tree jj ops are safe.

**Why this arm:** the 26y funnel (#2490) kills 36 % of monsters at the top-N cut; ranking has no skill, so the cut at 20
is a lottery; every faithful breakout-gate *width* dial is a settled REJECT (early_stage2 ≤4 validated, continuation
#1366, range-top not promotable) — capacity is the one open top-of-funnel lever, and it moves nothing else (size,
exposure, slots, grade floor unchanged). [[project_monster_funnel_top_of_funnel]],
[[project_concentration_deploy_probe_reject]], [[project_early_stage2_window_validated]].

**How to read it (pre-registered):** `sh paired.sh <null-trades.csv> <arm-trades.csv>` per salt → shared / null-only /
arm-only, first-divergence date, per entry-year realised, arm-only cohort by year with ≥ +20 % share. Arm clears only
if realised AND Calmar beat the null at ≥ 2/3 salts; if the arm-only cohort is ≥ 80 % losers at every salt the widening
is stale-entry breadth → REJECT with that why. From d0: the PIT-band funnel by phase per year (`Dropped_at_top_n`,
`Dropped_at_breakout` sub-reasons) — scope the arm's effect to the weeks where the null's list was cap-bound; if those
are < 10 % of weeks an inert arm is the expected finding. A d0 tripwire MISMATCH means build drift: stop the lane.

**Ledger entry to write:** `dev/experiments/_ledger/2026-09-2x-top-of-funnel-capacity.sexp`, baseline
`record-pit-null-v11pit`, window `top3000-pit-1999-2025-record-26y-3salt`. Results as a follow-up PR (the
pre-registration #2897 is already merged).
