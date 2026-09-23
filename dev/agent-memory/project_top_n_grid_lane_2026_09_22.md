---
name: top-n-grid-lane-2026-09-22
description: "⭐ 09-23 TOP-N GRID CELL 2 DONE (2019–25 sub-window, PIT, 3 salts): cap 40 TIGHTENS (37 vs 81 pp, 3.3 vs 4.9 pt) and is not dominated → 2-of-3 grid cells reached, cell 3 (top-1000 schedule) pending, default stays 20; cap 30 does NOT tighten (109.7 pp), cap 60 tightens but is DOMINATED (band above the null, means lower) — the dial is bounded above; ADMA 2023-12-19 tops the arm-only cohort at cap 40 on all 3 salts. Ledger amended in place."
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

**Interim result (09-23 01:11 PT, null + cap 40 done):** null s0/s1/s2 = 34.4 / −9.5 / 71.3 % (maxDD 43.4 / 48.3 / 43.8); cap 40 = 50.7 / 88.2 / 52.9 % (43.7 / 47.0 / 44.1). Ranges: realised 37.4 vs 80.9 pp, maxDD 3.3 vs 4.9 pt → TIGHTENS; means 63.9 vs 32.1 % and Calmar 0.160 vs 0.084 → not dominated; mechanism rule 2/3 (s2 fails). Cells 1+2 tighten → 2-of-3 reached; cell 3 (top-1000 schedule) is the confirmation. ADMA 2023-12-19 (+$327k) tops the arm-only cohort at every salt — cap-driven admission, salt-stable, ~+30 pp of the arm mean. Cap 30/60 cells pending (lane continues, ~09:30 PT). README §Interim read.

**FINAL cell 2 (09-23 07:36 PT, 12/12 cells, V6 = 0):** null ranges 80.9 pp / 4.9 pt (means 32.1 % / 0.084); cap 30 109.7 / 3.5 (73.4 / 0.185) → no; cap 40 37.4 / 3.3 (63.9 / 0.160) → TIGHTENS, not dominated; cap 60 66.9 / 2.1 (21.6 / 0.050) → tightens AND dominated (maxDD 47.9–50.0 above the null 43.4–48.3). Response non-monotone: 30 widens, 40 tightens, 60 tightens-and-sinks (s2 arm-only 99 trades −$335k = stale breadth). ADMA present at cap 40 s0/s1/s2, cap 30 s1, cap 60 s0 only. Next = cell 3: build top-1000 yearly lists as goldens top-1000 ∩ pit-v11 top-3000 per year, run null + cap 40 (+30/60 optional) × 3 salts on the 26y schedule of those lists; then, if it tightens without domination, the paired-golden table and a promotion PR. README §Verdict; ledger notes amended in place (no new entry).
