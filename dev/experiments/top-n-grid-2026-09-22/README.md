# Top-N confirmation grid — sub-window cells (2026-09-22)

**Status: PRE-REGISTERED** (written 15:10 PT 2026-09-22, before any cell ran; README, specs and chain pushed before the
first launch). The promotion-confirmation grid (`.claude/rules/promotion-confirmation.md`) for the one ACCEPT on the
table, `screening_config.max_buy_candidates` 20 → 40 (`_ledger/2026-09-22-top-of-funnel-capacity.sexp`, #2900). This
directory holds **cell 2** of the grid (period diversity: the 2019–2025 sub-window on the same PIT schedule); cell 1 is
the 26y record window already run in `top-of-funnel-2026-09-21/`; cell 3 (breadth tier: a top-1000 schedule) needs
yearly top-1000 lists that do not exist yet (only `pit-v11/composition/top-3000-*.sexp`; the lists are sorted by
`avg_dollar_volume` descending, so a top-1000 schedule is the first 1,000 entries of each — a build step, not a fetch).

## Why this and not P1 #1

The 09-23 priorities doc put a "slot-fill ordering dial (score → RS → volume ratio)" first. That dial exists —
`Screener.config.candidate_ranking = Quality` (#1786) — and the ledger already holds three verdicts on it:
`2026-06-29-candidate-ranking-tiebreak-grid` (RS-primary: REJECT, dominated in top-500, lower Calmar 3/3),
`2026-06-29-earliness-ranking-tiebreak-grid` (earliness-primary: REJECT, Pareto-dominated 3/3),
`2026-06-30-tiebreak-noise-floor` (uninformative sorts bracket a band both informative sorts sit inside; "candidate-
ranking lever is dead; the productive direction is to REDUCE selection variance via capacity / concentration, not
re-sort"). The old grids ran on thin warehouses (327 / 514 / 1,065 names with bars) and 2y fork-per-fold, so a
basis-change re-test is arguable — but a 3-salt rule that a coin flip clears ~50 % of the time cannot resolve a sort
whose level effect is, by the 06-30 mechanism, a re-draw. The 06-30 forward directive IS this grid: #2900's one
plausible robust property is a tighter salt band (arm realised 237–330 % vs null 152–457 %; maxDD 43.8–44.7 vs
40.6–53.0), i.e. capacity as a variance reducer. Memory: `feedback_check_ledger_before_proposing_a_dial`.

## Cells (specs/, run by chain-grid.sh from a pinned worktree `sweep-grid` = `ad5a9e04e`, the exact build of cell 1)

| cell | period | change vs `a0-pit-null` | salts |
|---|---|---|---|
| `a0-pit-null-sub` | 2019-01-01 → 2025-12-31 | none (cap 20) — the paired base for this window | 0 / 1 / 2 |
| `t1-topn-40-sub` | same | `((screening_config ((max_buy_candidates 40))))` — the #2900 value | 0 / 1 / 2 |
| `t1-topn-30-sub`, `t1-topn-60-sub` | same | cap 30 / cap 60 — the neighbours the rule asks for | 0 / 1 / 2 |

Everything else is the record spec verbatim (27-entry `universe_schedule`, D1/D2 dating, `_v11pit` warehouse with 9,364
entries — the chain aborts on any other count, `SNAPSHOT_MAX_MMAP_HANDLES=12000`). The null is re-run on this window
(no committed null exists for it); each arm cell pairs against the null cell of the same salt from this lane
(`validator_diff -check V6` exit 0 required for the pair to count — `mechanism-validation-rigor.md` check 8).

**Order:** null s0 / s1 / s2 first (`feedback_run_the_null_control_first`), then cap 40 s0–s2, then 30, then 60. The
lane is resumable (a `RESULT` line skips the cell); the 30 / 60 cells are lower priority and may run in a later session.

## Pre-registered decision rule (dispersion, not level)

The grid criterion is the property #2900 found, applied per cell: **a value V "tightens" a cell if the 3-salt range of
realised return AND the 3-salt range of maxDD are both narrower than the null's 3-salt ranges in that cell.** Cell 1
(26y): cap 40 tightens (93 pp vs 305 pp; 0.9 pt vs 12.4 pt).

- **PROMOTE-eligible V** (proceed to the paired-golden table, `config-default-blast-radius.md`, and a promotion PR
  citing this README + the ledger ACCEPT) only if V tightens **≥ 2 of the 3 cells** AND is **never dominated** in any
  cell (dominated = lower mean realised AND lower mean Calmar than the null's 3-salt means). Level gains are not a
  criterion; the mechanism rule (realised AND Calmar better at ≥ 2/3 salts) is reported per cell, not required.
  *[Clarified 2026-09-24, #2935 qc-results A2: "≥ 2 of 3" is necessary, not sufficient — all three cells must run and
  §Cell 3 resolves it to a strict 3-of-3 requirement. Quote the §Cell 3 branch table, not this clause.]*
- With only cells 1 and 2 available, the strongest outcome here is **"2/3 reached, cell 3 pending"** (if 40 tightens
  the sub-window and is not dominated) or **"cell 2 fails to tighten — 40 needs cell 3 to tighten to stay alive"**. No
  promotion PR is opened from this directory alone.
- Neighbours: if 30 or 60 tightens where 40 does not, the promotable candidate becomes the neighbour that tightens in
  the most cells, per `promotion-confirmation.md` ("often a neighbour of the per-window winners").
- n = 3 ranges are weak (three draws; the 26y null's s0 may be the outlier — #2900 §Verdict 2). The grid is the
  pre-registered standard, not a power claim; the writeup must say PLAUSIBLE, and the ledger entry records the grid
  outcome as an amendment to `top-of-funnel-capacity`, not a new ACCEPT.

Mechanism read per (cell, salt): `paired.sh <null-trades.csv> <arm-trades.csv>` (join key `symbol|entry_date`) →
shared / null-only / arm-only cohorts with realised P&L, first-divergence date, per-entry-year table, ≥ +20 % share.
On this window the regime framing of `project_pit_drawdown_2021_25_macro_veto` (≥ +20 % winners 10 % → 2 % of entries
after 2021-11) is most of the sample, so the per-entry-year read is the one that matters.

## Cost / ops

No 7y cell has been measured on this build class. The 26y arm cells ran 3h59m–4h48m at cap 12,000 (~11 min per
simulated year), so ~80 min per 7y cell is the projection; the chain's `CELL_TIMEOUT=14400` is 3× that and is
re-sized from the first cell's measured wall (≥ 1.5×). 12 cells ≈ 16 h at the projection; the first six (null + cap 40)
≈ 8 h. One lane, container-exclusive (`container-capacity-scheduling.md` rule 1: no agents while a cell runs; QC on
open PRs runs first, rule 0). Specs staged at `/tmp/grid-run/specs` (outside any VCS tree), artifacts at
`/tmp/sweeps/top-n-grid/` (bind-mounted), per-cell raw artifacts committed to `results/` after each cell
(`feedback_commit_raw_per_arm_artifacts`; the chain's summary line is scoped to `${out}/<name>/actual.sexp`). Each cell
logs GNU-time peak RSS and the `snapshot cache` line.

## Log

- 2026-09-22 15:10 PT — pre-registered. Worktree `sweep-grid` pinned at `ad5a9e04e`; build + launch wait for the
  harness agent wave (#2887 / #2891 / #2896) and its QC to clear the container.
- 2026-09-22 15:10–17:43 PT — pre-registration merged as #2917 (CI + qc-results APPROVED, quality 4; the two chain
  advisories — a binary tripwire in the preamble and keeping each cell's V6 diff log — are the chain commit below; the
  first preamble draft named `scenarios/bin/scenario_runner.exe`, a path that does not exist, and was fixed before
  launch). **Lane A launched 17:43 PT** from `sweep-grid` @ `ad5a9e04e` (runner md5 `683b4885da8cbf9e3e25d760ab444131`),
  cap 12,000, guard 14,400 s, order null s0/s1/s2 → cap 40 s0–s2 → cap 30 → cap 60; chain + specs staged under
  `/tmp/grid-run/` (host), artifacts `/tmp/sweeps/top-n-grid/` (container), log `/tmp/grid-run/chain-A.log`. Container
  was idle at launch (345 MB; the harness wave #2918/#2919/#2920 had merged); host free 63 G after thinning 18 Time
  Machine local snapshots that pinned the day's deleted agent worktrees (15 G → 64 G). Re-size `CELL_TIMEOUT` from the
  first cell's wall before reading anything else.
- 2026-09-23 01:11 PT — **null + cap 40 done (6 of 12 cells), V6 diff exit 0 on every pair; cap 30 s0 running.** Walls
  99 / 78 / 59 min (null) and 66 / 72 / 73 min (cap 40) — the 14,400 s guard is 2.4× the slowest, no re-size. Peak RSS
  5.05–5.11 GB, `evictions=0` every cell. Per-cell raw artifacts + `<tag>-v6diff.log` + per-salt `paired.sh` reads are
  in `results/` (the `-v6diff` spelling is deliberate: the qc-results glob, per the #2923 review).

## Interim read — cell 2 (2019–2025 sub-window), cap 40 (2026-09-23; cap 30 / 60 pending)

| salt | null: return / maxDD / Calmar | cap 40: return / maxDD / Calmar | realised | Calmar |
|---|---|---|---|---|
| s0 | 34.4 / 43.4 / 0.099 | 50.7 / 43.7 / 0.138 | clear (+16 pp) | clear |
| s1 | −9.5 / 48.3 / −0.029 | 88.2 / 47.0 / 0.201 | clear (+98 pp) | clear |
| s2 | 71.3 / 43.8 / 0.183 | 52.9 / 44.1 / 0.142 | fail (−18 pp) | fail |

**Pre-registered dispersion rule, cell 2:** null 3-salt ranges — realised **80.9 pp** (−9.5 → 71.3), maxDD **4.9 pt**
(43.4 → 48.3); cap 40 — realised **37.4 pp** (50.7 → 88.2), maxDD **3.3 pt** (43.7 → 47.0). Both narrower → **cap 40
TIGHTENS cell 2.** Not dominated: mean realised 63.9 vs 32.1 %, mean Calmar 0.160 vs 0.084 (both higher). Mechanism
rule (reported, not required): 2 of 3 salts clear both metrics — the same 2/3 pattern as cell 1, with the failing salt
again the one where the null's draw holds the strongest cohort (s2 here, s0 on 26y).

**Grid status for cap 40: cells 1 and 2 both tighten → the ≥ 2-of-3 condition is REACHED, cell 3 (top-1000 schedule)
pending as the confirmation that it is not two draws.** No promotion PR from this directory (README §Decision rule);
the ledger amendment waits for cap 30 / 60 (a neighbour that tightens in more cells, or is never dominated where 40 is,
would become the candidate).

Caveats the writeup must carry (PLAUSIBLE, n = 3 per cell): (1) the null's realised band on this window is a sign flip
(−9.5 → 71.3 %) on 260–281 trades — a 7y window of the 2021–25 grind (`project_pit_drawdown_2021_25_macro_veto`) is
mostly noise; (2) the arm's level is again one trade: **ADMA 2023-12-19 (+$327 k) is the top arm-only winner at ALL
THREE salts** (s0 $327,320 / s1 $326,602 / s2 $326,895), i.e. a cap-driven admission that is stable across path salts,
not a slot re-draw — the first arm-only name in this program that is robust to the salt, and it alone is ~+30 pp of
the arm's mean; (3) the maxDD "tightening" is 1.6 pt on a 4.9 pt band — small in absolute terms; realised is the axis
that moved. Per-salt cohorts: arm-only 76 / 80 / 83 trades at +$278 k / +$408 k / +$276 k, null-only 73 / 95 / 68 at
+$241 k / −$184 k / +$352 k; shared 197 / 186 / 192 (arm vs null pnl on the shared cohort: −66 vs −117 k$ at s0, +6 vs +54 k$ at s1, −66 vs −117 k$
at s2 — better at two salts, WORSE by $48 k at s1, so NOT a robust property; at s1, the salt where the arm beats the null by
+98 pp, none of the gain comes from shared trades — it is entirely the arm-only cohort (+$408 k) plus the null-only drag
(−$184 k), which is where a dissection should start).

Open question for the writeup: is ADMA 2023-12-19 a rank 21–40 admission or a null-admitted-never-filled name? Needs a
`--emit-candidates` diagnostic cell on the null s0 of this window (`d0`-style, ~2× wall) — not run in this lane.
- 2026-09-23 07:36 PT — **LANE A DONE, 12 of 12 cells, V6 diff exit 0 on all nine pairs.** Walls 59–99 min (null),
  60–73 min (arms); guard never approached. Peak RSS 5.05–5.13 GB, `evictions=0` throughout. `results/chain-A.log`
  archived; worktree `sweep-grid` and `/tmp/grid-run` removed; `/tmp/sweeps/top-n-grid` (83 MB) kept in the container.
  Interim null + cap 40 results merged as #2925 (one qc-results rework: the shared-cohort claim was 2-of-3, not 3-of-3).

## Verdict — cell 2 (2019–2025 sub-window, PIT top-3000 schedule), pre-registered dispersion rule (2026-09-23)

| value | s0: return / maxDD / Calmar | s1 | s2 | realised range | maxDD range | mean return | mean Calmar | tightens? | dominated? |
|---|---|---|---|---:|---:|---:|---:|---|---|
| null (cap 20) | 34.4 / 43.4 / 0.099 | −9.5 / 48.3 / −0.029 | 71.3 / 43.8 / 0.183 | 80.9 pp | 4.9 pt | 32.1 % | 0.084 | — | — |
| cap 30 | 20.4 / 43.7 / 0.062 | 130.2 / 40.3 / 0.314 | 69.5 / 43.4 / 0.180 | **109.7 pp** | 3.5 pt | 73.4 % | 0.185 | **no** (realised wider) | no |
| cap 40 | 50.7 / 43.7 / 0.138 | 88.2 / 47.0 / 0.201 | 52.9 / 44.1 / 0.142 | 37.4 pp | 3.3 pt | 63.9 % | 0.160 | **yes** | no |
| cap 60 | 60.2 / 50.0 / 0.139 | 11.4 / 48.6 / 0.032 | −6.7 / 47.9 / −0.021 | 66.9 pp | 2.1 pt | 21.6 % | 0.050 | yes | **yes** (both means lower) |

Mechanism rule per value (reported, not required — realised AND Calmar better than the null at the same salt): cap 30
1/3 (s1), cap 40 2/3 (s0, s1), cap 60 2/3 (s0, s1).

**Cap 40 is the only value that tightens cell 2 without being dominated.** Cap 30's realised band is wider than the
null's (20 → 130 %: its s1 draw holds ADMA + TMQ + GLNG, its s0 draw holds none of them). Cap 60 has the narrowest
bands of all four but its maxDD band (47.9–50.0) sits above the null's (43.4–48.3) at every salt but one (47.9 vs 48.3 at s2) and its mean return and
Calmar are both below the null's — "never dominated" is exactly the clause the rule needs here: a tight band around
a worse level is not the property being tested. The response to the cap is therefore not monotone: 30 widens, 40
tightens, 60 tightens-and-sinks. With cell 1 (26y record window, cap 40 tightens: 93 vs 305 pp, 0.9 vs 12.4 pt), **cap
40 has reached the ≥ 2-of-3 condition; cell 3 (a top-1000 schedule, breadth diversity) is the pending confirmation
and no promotion PR opens from this directory** (§Decision rule). A promotion PR, if cell 3 tightens, still needs the
paired-golden table (`config-default-blast-radius.md`) and cites this README + the ledger amendment.

What three salts on one 7-year window can and cannot say (PLAUSIBLE, n = 3 per value):
1. **The level is one trade at every cap.** ADMA 2023-12-19 is the top arm-only winner at cap 40 s0/s1/s2 ($327 k
   each), cap 30 s1 ($399 k) and cap 60 s0 ($303 k), and absent at cap 30 s0/s2 and cap 60 s1/s2 — the widened list
   admits it at cap 40 regardless of path, at the neighbours only on some paths. Whether it is a rank-21–40 admission
   or a null-admitted-never-filled name needs a `--emit-candidates` diagnostic on this window (not run; ~2× wall).
2. **Where cap 60 loses:** s2 arm-only 99 trades at −$335 k (top winner only $80 k) against null-only 80 at +$32 k —
   the 60-name list's extra admissions are stale-entry breadth on the 2021–25 grind, the failure shape
   `project_early_stage2_window_validated` recorded for width dials; cap 60 is the first of the three points where
   widening is worse than the null on both means, which bounds the dial from above on this window.
3. **The maxDD "tightening" at cap 40 is 1.6 pt on a 4.9 pt band** — realised is the axis that moved, and on the
   26y cell it was the reverse (maxDD 0.9 vs 12.4 pt was the striking one). Two cells tightening on different axes
   is weaker evidence than two cells tightening on the same axis; cell 3 should be read on both.
4. The null's own band is a sign flip on 260–281 trades; every comparison here is against a noisy reference.

Ledger: `_ledger/2026-09-22-top-of-funnel-capacity.sexp` notes AMENDED 2026-09-23 with this cell (no new entry, no
new ACCEPT; the mechanism verdict is unchanged). Memory `project_top_n_grid_lane_2026_09_22`.

## Cell 3 — breadth tier (yearly top-1000 PIT schedule, 26y record window) — PRE-REGISTERED 2026-09-23

**Status: PRE-REGISTERED** (written 13:10 PT 2026-09-23, before any cell-3 cell ran; lists, specs, chain and this section
pushed before the first launch). Cell 3 is the third context the grid needs for cap 40 (cells 1 and 2 both tighten):
`promotion-confirmation.md` §"Universe diversity — BROAD vs BROAD only" — the breadth tier, a **top-1000 schedule vs the
top-3000 schedule, built from the same yearly lists with the same D1/D2 dating.** Period = the 26y record window
(2000-01-01 → 2026-06-26, as cell 1), so cell 3 moves exactly one axis against cell 1 (breadth) and one against cell 2
(period AND breadth — cell 3 is not compared to cell 2 directly).

### Construction (`build-top1000.sh` → `universe/top-1000-{1999..2025}.sexp`, 27 lists)

Per year Y: every entry of the as-run `pit-v11/composition/top-3000-Y.sexp` whose `avg_dollar_volume` ≥ the smallest
`avg_dollar_volume` in `goldens-custom-universe/composition/top-1000-Y.sexp`. Both lists are sorted by
`avg_dollar_volume` desc and the goldens top-1000 is the first 1,000 rows of the goldens top-3000 (rank of that minimum
in the goldens top-3000 = 1,000, checked), so the cut is "the goldens top-1000 members present in the `_v11pit`
warehouse, AFTER the 09-14 / 09-15 alias passes" (`pit-universe-2026-09-14/step4/specs/alias2.resolved` +
`pit-universe-2026-09-14/step4/twin-scan/alias3.txt`). A plain symbol intersection would drop the aliased twins — 1999: 969 by threshold vs 958 by
symbol, the 11 extras all alias targets (XL_old → XL, Q_old1 → IQV, HLX → HOS, ATHYQ/BGEN → BCAL, …). Entries are copied
verbatim except `(weight)` = 1/N and `(size)` = N (the pit-v11 top-3000 lists kept `size 3000` / weight 1/3000 with
~2,820 entries — the runner reads membership only, neither convention changes a run); `aggregate_period_return` is
carried from the goldens top-1000 list. **Present names per year: 928 (2009) → 998 (2025)**, i.e. ~94 % of each
top-1000 has bars, vs ~2,846 / 3,000 (27-list mean; range 2,792–2,993) for the top-3000 schedule — the breadth tier is 1/3 the names, not a different
warehouse (`_v11pit`, 9,364 entries, unchanged; the chain aborts on any other count).

The lists live under `universe/` in this directory (results-only lane; `feedback_commit_raw_per_arm_artifacts`) and are
staged by `chain-cell3.sh` into the pinned run tree as `pit-v11/composition/top-1000-YYYY.sexp` — untracked files, so
the chain's dirty check still guards tracked code; the chain logs `md5(cat)` of the 27 lists. If cap 40 is promoted,
the promotion PR moves the lists under `trading/test_data/backtest_scenarios/pit-v11/composition/` (a code-tree PR, full
three gates).

### Cells (`specs/`, run by `chain-cell3.sh` from `sweep-grid` re-pinned at `ad5a9e04e` — the exact build of cells 1 and 2)

| cell | period | change vs the null | salts |
|---|---|---|---|
| `a0-pit1000-null` | 2000-01-01 → 2026-06-26 | none (cap 20) on the top-1000 schedule — the paired base for this cell | 0 / 1 / 2 |
| `t1-topn-40-1000` | same | `((screening_config ((max_buy_candidates 40))))` — the #2900 value | 0 / 1 / 2 |

Everything else is the cell-2 spec verbatim (27-entry `universe_schedule`, D1/D2 dating, `SNAPSHOT_MAX_MMAP_HANDLES=12000`,
`universe_size 1000`). Cap 30 / 60 are NOT run here: both failed cell 2 (30 widens, 60 is dominated), so neither can
reach 2 of 3 cells whatever cell 3 says. **Order:** null s0 / s1 / s2, then cap 40 s0 / s1 / s2 — six cells, one lane,
container-exclusive; each arm pairs against the null of the same salt (`validator_diff -check V6` exit 0 required).

### Pre-registered decision rule (unchanged from §above, applied to cell 3)

Cap 40 **tightens** cell 3 if its 3-salt range of realised return AND of maxDD are both narrower than the null's on
this schedule; **dominated** if its mean realised AND mean Calmar are both below the null's. Outcomes:

- **tightens, not dominated → 3 of 3 cells → cap 40 is PROMOTE-ELIGIBLE**: next is the paired-golden table
  (`config-default-blast-radius.md`; `max_buy_candidates` is a `screening_config` default, so `goldens-affected` will
  fire) and a promotion PR citing this README + the ledger amendment. The promotion is still a default flip on
  n = 3 per cell — the PR body carries the PLAUSIBLE framing and the one-trade caveats from cells 1 and 2.
- **does not tighten, not dominated → 2 of 3 stands, cell 3 disagrees**: no promotion; record the breadth
  dependence, keep cap 40 as an axis (`experiment-flag-discipline.md` R1–R2; the ledger ACCEPT is unchanged).
- **dominated (either way)** → the "never dominated" clause fails → NOT promotable; ledger amendment records it.
  *[Classification added 2026-09-24 per #2935 qc-results A3 — written AFTER the cell-3 result, so it is not
  pre-registered: REJECT-as-default / keep-as-axis. The mechanism ACCEPT and the `max_buy_candidates` knob are unchanged;
  the value is simply not promotable. It is not do-not-revive: cells 1–2 still show the dispersion property on the
  top-3000 schedule.]*

Mechanism rule (realised AND Calmar better at ≥ 2/3 salts) is reported, not required. Per-salt cohort read with
`paired.sh` (join key `symbol|entry_date`); the top arm-only winner per salt is named, because on cells 1 and 2 the
level was one trade (DDS-class on 26y, ADMA 2023-12-19 on the sub-window) — on a top-1000 schedule ADMA (rank 2,248 by
dollar volume in the 2023 goldens top-3000; 2,935 in 2022, 1,712 in 2024) is not a member, so cell 3 also tests whether the tightening survives losing that one name.
*[Corrected 2026-09-24, #2935 qc-results A1: ADMA is absent from `top-1000-2023`, the list that governs the 2023-12-19
entry under D1/D2, so that admission cannot recur; it first enters the top-1000 in the 2025 list, which governs
2025-05-31 → 2026-06-26. "Not a member" above means "not a member of the 2023 list".]*

### Cost / ops

No 26y top-1000 cell has been measured. The 26y top-3000 arm cells ran 3h59m–4h48m; fewer members should mean fewer
screened names per week but the union warehouse and the weekly classify are unchanged (#2839), so the projection is
2–4 h per cell, 12–24 h for six. `CELL_TIMEOUT=28800` (1.67× the slowest top-3000 arm cell); re-size from the first
cell's wall (≥ 1.5×). Artifacts `/tmp/sweeps/top-n-grid-cell3/` (container, bind-mounted), specs and lists staged at
`/tmp/grid-run/{specs,universe}` (outside any VCS tree), log `/tmp/grid-run/chain-C3.log`. Per-cell raw artifacts are
committed to `results/` with the `-1000` suffix in the tag.

### Log — cell 3

- 2026-09-23 13:08 PT — lane C3 launched (`sweep-grid` @ `ad5a9e04e`, runner md5 `683b4885…`, lists md5(cat)
  `a8cdb607…`, 928–998 names/yr, warehouse 9,364). Paused 13:48 PT at ~40 min into null s0 for the #2936–#2939 QC wave
  (`container-capacity-scheduling.md` rule 0); relaunched 16:40 PT, null s0 rerun from scratch.
- 2026-09-24 06:51 PT — lane C3 DONE, 6/6 cells. Wall 8,250–8,780 s per cell (2h18m–2h26m, **~55 % of a top-3000 26y
  cell**); peak RSS 3.09–3.15 GB; cache 0 evictions. The 28,800 s guard was ~3.3× the measured cell — re-size any
  future top-1000 26y lane to ≥ 13,200 s (1.5× the slowest, 8,780 s). Raw per-cell artifacts in `results/*-1000-*` +
  `results/chain-C3.log`; per-salt reads `results/t1-topn-40-1000-s{0,1,2}-read.md`.

## Verdict — cell 3 (26y record window, yearly top-1000 PIT schedule), pre-registered dispersion rule (2026-09-24)

Every figure below is read from `results/<arm>-s<N>-actual.sexp` (metric-glob tripwire: one `total_return_pct` per
file, and per line of `chain-C3.log`).

| arm | s0 realised / maxDD / Calmar | s1 | s2 | realised range | maxDD range | mean realised | mean Calmar |
|---|---|---|---|---|---|---|---|
| null (cap 20) | 543.1 % / 32.15 / 0.226 | 465.6 / 31.36 / 0.216 | 337.3 / 31.29 / 0.183 | 205.8 pp | 0.87 pt | 448.7 % | 0.208 |
| cap 40 | 231.5 / 36.25 / 0.128 | 225.1 / 33.15 / 0.137 | 404.1 / 39.18 / 0.161 | 179.0 pp | 6.04 pt | 286.9 % | 0.142 |

**Branch (§Cell 3 table): DOMINATED → cap 40 is NOT promotable.** Mean realised 286.9 % < 448.7 % AND mean Calmar
0.142 < 0.208. It also does **not tighten**: the realised range narrows (179.0 vs 205.8 pp) but the maxDD range widens
~7× (6.04 vs 0.87 pt), and every cap-40 maxDD (33.1–39.2) sits above every null maxDD (31.3–32.2). Mechanism rule
(reported, not required): realised AND Calmar better at **0 of 3** salts (s2 realised better, Calmar worse). The grid
reads cell 1 tightens / cell 2 tightens / **cell 3 dominated** → the "never dominated in any cell" clause fails.
Default stays 20. **Classification: REJECT-as-default / keep-as-axis** (A3 annotation above; written after the result,
so not pre-registered). The ledger ACCEPT(mechanism) from the 26y top-3000 surface is unchanged.

**V6 gate — two of three pairs fail, the verdict does not rest on them.** `validator_diff -check V6` exit 1 on s0 and s1:
the null holds one twin, **IAC/MTCH 2012-03-15** (both tickers entered the same day, 4-day hold, stop_loss, +$719 each
leg on ~$119 k — a ~$0.7 k duplicated P&L on a $1 M start). The arms hold different instrument sets on those salts, so
the per-salt s0/s1 deltas are not clean mechanism reads (`mechanism-validation-rigor.md` check 8). Two bounds keep the
verdict: (1) the direct effect is ~0.07 pp of return against a 161.8 pp gap in mean realised; (2) **the arms first
diverge on 2000-04-04 at every salt** (`paired.sh`), 12 years before the twin, so the twin is not what separates them
— path effects after 2012-03-15 are not bounded, but they would have to flip the sign of a gap that already exists. s2
(exit 0) is the one clean pair and reads cap 40 +66.8 pp realised, −0.022 Calmar, +7.9 pt maxDD: better level, worse
risk — not "tightening" either. The twin is the known chunked-build alias class (`project_pit_chunked_twin_miss`);
it is a data defect in the top-1000 lists inherited from the top-3000 build, not new to this cell.

**Per-salt cohorts (`results/t1-topn-40-1000-s{0,1,2}-read.md`, join `symbol|entry_date`).**

| salt | shared n | null-only n / P&L | arm-only n / P&L | top arm-only | top null-only |
|---|---|---|---|---|---|
| s0 | 483 | 252 / +$1.96 M | 287 / +$0.19 M | TPL 2021-01-11 +$354 k | BBWI 2020-08-05 +$888 k, TSLA 2013-04-03 +$678 k |
| s1 | 498 | 243 / +$2.81 M | 261 / +$0.85 M | WMB 2024-03-23 +$192 k | AMAT 2020-11-07 +$720 k, ANET 2016-11-12 +$366 k |
| s2 | 483 | 280 / +$1.63 M | 286 / +$2.09 M | BBWI 2020-08-05 +$539 k, ANET 2016-11-12 +$334 k | TSLA 2013-04-03 +$627 k, SHOP 2020-04-14 +$497 k |

The level is the same monster lottery as cells 1–2: whichever arm's draw holds BBWI-2020 / TSLA-2013 / AMAT-2020 /
ANET-2016 wins the salt (s2 is the salt where the arm drew BBWI + ANET). ADMA 2023-12-19 — the cell-2 level trade —
cannot enter here (absent from `top-1000-2023`, A1), and **the cell-2 tightening did not survive losing it**, which
answers the question §Cell 3 pre-registered.

**Why (hypothesis, not measured here).** On a top-1000 pool the admitted list is 1/3 the size, so ranks 21–40 are drawn
from a thinner, lower-quality tail than on top-3000, while the book still fills ~5 slots. Widening the cap re-draws
which resting orders trigger first (the d0 mechanism: slot policy, not screener capacity) and here the re-draw lands
more often on the tail — the arm-only cohort is weak at 2 of 3 salts and every arm's maxDD is worse. What this rules
in/out: the dispersion-tightening seen on top-3000 is **breadth-dependent**, so cap width is not a universe-free
variance reducer; do not propose further cap-width points as a default. The standing forward lever from the ledger
(slot-fill ordering when admitted > open slots) is unaffected by this cell — and per
`feedback_check_ledger_before_proposing_a_dial` its score-ordering variant (`candidate_ranking = Quality`) is already
REJECTED, so any follow-up must be a different ordering, checked against the ledger first.

**Side observation, not a verdict:** the top-1000 null (mean 448.7 %, maxDD band 31.3–32.2) sits well above the cell-1
top-3000 null (152–457 %, maxDD 40.6–53.0) on the same window and build. That is a cross-cell comparison the grid was
not designed for (§Cell 3: cell 3 moves only breadth against cell 1, and n = 3); it is recorded as a lead for a
breadth-tier question, not as evidence that narrowing the universe helps.
