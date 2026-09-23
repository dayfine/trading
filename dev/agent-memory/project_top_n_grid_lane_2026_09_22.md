---
name: top-n-grid-lane-2026-09-22
description: "IN FLIGHT 09-22 17:43 PT: top-N confirmation grid cell 2 (2019–2025 sub-window, PIT schedule) — null + cap {40,30,60} × 3 salts, lane A from sweep-grid @ ad5a9e04e; pre-registered #2917 (dispersion rule: 3-salt realised AND maxDD ranges narrower than the null's, promote-eligible at ≥ 2/3 cells, never dominated). Cell 3 (top-1000 schedule) needs lists = goldens top-1000 ∩ pit-v11 top-3000 per year."
metadata:
  type: project
---

**State:** `dev/experiments/top-n-grid-2026-09-22/` (README, specs, chain-grid.sh, paired.sh). Lane A: `EXPECT_HEAD=ad5a9e04e sh
/tmp/grid-run/chain-grid.sh A <12 cells>`, log `/tmp/grid-run/chain-A.log`, artifacts `/tmp/sweeps/top-n-grid/<tag>-*`
(tag = `<spec>-s<salt>`), guard 14,400 s (re-size from the first cell: 26y arm cells ran ~11 min/simulated year → ~80 min
projected for 7y). Order: null s0/s1/s2, cap 40 s0–s2, cap 30, cap 60. Resumable (RESULT line = SKIP). Chain-tweak commit
(binary tripwire + V6 log copy) is local, unpushed, to ship with the results PR (results-only lane → qc-results).

**Read:** per salt `sh paired.sh <null-trades.csv> <arm-trades.csv>` (join `symbol|entry_date`); V6 diff exit 0 required per
pair; ranges over 3 salts per value vs the null's; ledger outcome = AMENDMENT to `2026-09-22-top-of-funnel-capacity`, not a
new ACCEPT. No promotion PR from cell 2 alone.

**Why it exists (and why not P1 #1):** [[feedback_check_ledger_before_proposing_a_dial]] — the "slot-fill ordering" dial is
`candidate_ranking=Quality`, REJECTED 06-29 ×2 + noise-floor 06-30; that ledger's forward directive (capacity/concentration
as a variance reducer) IS this grid. Related: [[project_top_n_capacity_verdict]], [[project_promotion_confirmation_grid]].

**Cell 3 prep:** yearly `top-1000-YYYY.sexp` exist under `trading/test_data/goldens-custom-universe/composition/` but the
pit-v11 top-3000 lists drop ~333 names/year absent from the warehouse (e.g. 2019: 58 of the top-1000 are absent), so a
top-1000 schedule must be filtered to the pit-v11 symbol set per year before use (lists are sorted by avg_dollar_volume
desc, 0 violations) — a small OCaml/awk build step, not a fetch.
