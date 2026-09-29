---
name: top-n-grid-lane-2026-09-22
description: "⭐ 09-24 GRID CLOSED: cell 3 (top-1000 PIT, 26y) cap 40 DOMINATED (mean 287 vs 449 %, Calmar 0.142 vs 0.208, maxDD band 6.0 vs 0.9 pt) → never-dominated fails → NOT promotable, default 20, REJECT-as-default/keep-as-axis; dispersion tightening is BREADTH-DEPENDENT (cells 1–2 top-3000 tightened). PR #2945. V6 fails s0/s1 on IAC/MTCH 2012 twin (bounded: arms diverge 2000-04-04)."
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

**CELL 3 LAUNCHED 09-23 13:08 PT (breadth tier, 26y record window, top-1000 PIT schedule):** pre-registered as PR #2935
(README §Cell 3; qc-results dispatched 13:25 PT). Construction = `build-top1000.sh`: per year keep every as-run pit-v11
top-3000 entry with `avg_dollar_volume` ≥ the min of the goldens `top-1000-YYYY` (rank of that min in the goldens top-3000
= 1,000, checked) — this is "goldens top-1000 present in `_v11pit` AFTER the two alias passes"; a plain symbol
intersection MISSES the aliased twins (1999: 969 vs 958; all 11 extras trace to alias2.resolved/alias3.txt — XL_old→XL,
Q_old1→IQV, HLX→HOS, ATHYQ/BGEN→BCAL). 928 (2009) – 998 (2025) names/yr, weight 1/N, size N; lists live at
`dev/experiments/top-n-grid-2026-09-22/universe/` and the chain (`chain-cell3.sh`) stages them as UNTRACKED files into
the pinned run tree (`sweep-grid` @ `ad5a9e04e`, runner md5 683b4885… = cells 1–2; md5(cat lists) a8cdb607…). Specs
`a0-pit1000-null` / `t1-topn-40-1000` (cap 30/60 NOT run — both failed cell 2). Lane C3: log `/tmp/grid-run/chain-C3.log`,
artifacts `/tmp/sweeps/top-n-grid-cell3/`, guard 28,800 s (1.67× slowest 26y top-3000 arm; re-size from cell 1's wall).
Order null s0/s1/s2 → cap 40 s0/s1/s2. Outcome map: tightens + not dominated → 3/3 → promote-eligible → paired-golden
table + promotion PR (`max_buy_candidates` is a `screening_config` default → `goldens-affected` fires); else keep as axis.
ADMA is NOT in any top-1000 list (rank 2,248 in the 2023 goldens top-3000), so cell 3 also tests whether cell 2's
tightening survives losing its one-trade level.

**09-23 relaunch:** lane C3 was paused 13:48 PT (cell 1 at 40 min) for the four-PR harness QC wave (#2936–#2939, all merged
by 16:35 PT) and RELAUNCHED 16:40 PT with the same command; preamble tripwires identical. First `RESULT` (null s0) sizes
the guard. Two 3.5-day-old zombie `dune` pids (ppid 1, unkillable, no cwd) live in the container and trip a naive
`pgrep -x dune` idle check — count real builds by `/proc/<pid>/cwd` instead.

**CELL 3 DONE 09-24 06:51 PT → GRID CLOSED, cap 40 NOT promotable (PR #2945, ledger GRID AMENDMENT 2).** Null
543.1/465.6/337.3 % (maxDD 32.15/31.36/31.29), cap 40 231.5/225.1/404.1 % (36.25/33.15/39.18): ranges 205.8 vs 179.0 pp,
0.87 vs 6.04 pt; means 448.7 vs 286.9 %, Calmar 0.208 vs 0.142 → DOMINATED, does not tighten, mechanism 0/3. Classified
REJECT-as-default / keep-as-axis (post hoc). V6 exit 1 on s0/s1 (null-only IAC/MTCH 2012-03-15 twin, 4-day +$719/leg); arms
diverge 2000-04-04 at every salt so the twin does not separate them (null led 1.603 vs 1.432 M s0, 1.557 vs 1.443 M s1 on 2012-03-14). CALIBRATION: NOT-PROMOTABLE holds with s0/s1 discarded, but the DOMINATED label rests on them (s2 alone is not dominated). ADMA loss is CONSISTENT WITH, not proof of, cell 2 resting on one name — cell 3 drops ~2/3 of the names (confounded with breadth). Corrections PR #2947. Same monster lottery (BBWI-2020, TSLA-2013,
AMAT-2020, ANET-2016). WHY (hypothesis): tightening is breadth-dependent — do not propose cap-width points as a default.
Side lead only: top-1000 null (449 % mean, maxDD 31–32) sits well above the cell-1 top-3000 null on the same window.
Top-1000 26y cell = 2h18m–2h26m, 3.1 GB peak RSS. `sweep-grid` worktree + `/tmp/grid-run` removed 09-24.
