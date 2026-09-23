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
+$241 k / −$184 k / +$352 k; shared 197 / 186 / 192 (arm pnl on the shared cohort ≥ null's at every salt: −66 vs −117,
+6 vs +54, −66 vs −117 k$ — the second and only other robust property: the arm's shared trades lose less at s0 and s2,
and the cause is not yet dissected).

Open question for the writeup: is ADMA 2023-12-19 a rank 21–40 admission or a null-admitted-never-filled name? Needs a
`--emit-candidates` diagnostic cell on the null s0 of this window (`d0`-style, ~2× wall) — not run in this lane.
