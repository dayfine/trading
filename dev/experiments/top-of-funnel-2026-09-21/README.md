# Top-of-funnel capacity on the PIT band — P1 #3 of the 09-21 queue (2026-09-21)

**Status: PRE-REGISTERED** (written 14:05 PT 2026-09-21, before any cell ran; this README, the specs and the chain are
pushed before the first launch). One arm, three salts, paired against the committed PIT record null, plus one
diagnostic cell that changes no behaviour.

## Why

- `project_monster_funnel_top_of_funnel` (#2490, 26y top-3000, book-faithful monster set v2 = 1,303 episodes ≥ +100 %):
  surfaced 90.9 % → **breakout gate kills 51.0 %** → **top-N capacity kills 36.4 %** → grade 0 → admitted 3.5 % →
  held ≥ 13 wk 0.6 %. Funding and stop levers operate *below* the leak — every capital-management program (G2/G3,
  concentration 0.25, exposure / cash floor) has been REJECT or inert because almost no monster survives to where they
  act (`project_funding_grid_monster_lottery`, `project_concentration_deploy_probe_reject`: "the next entry-side
  screens widen the funnel (breakout-gate width, top-N)").
- The two top-of-funnel dials, and what the record already says about each:
  - **Breakout-gate width** (`Dropped_at_breakout`, sub-reason 94 % `Stage_setup` on the only decomposed read, a
    recovery-2023 smoke — direction only). `Stage_setup` = no admission arm fired: MA-cross freshness window,
    continuation arm, virgin re-admission. Every faithful width dial on it is already settled: `early_stage2_max_weeks`
    widening is a terminal REJECT (stale-entry admission, monotonic bear tax; `project_early_stage2_window_validated`),
    continuation buys REJECT (#1366), `Range_top_breakout` freshness is a drawdown lever that is not promotable and
    needs its anchor knob (`project_rangetop_freshness_is_a_drawdown_lever`, `project_rt_needs_its_anchor_knob`). **No
    open width dial remains on this base** — the 26y decomposition on the PIT band is still worth having (the d0 cell
    below), but it informs a preset, not another single-lever screen.
  - **Top-N capacity** (`screening_config.max_buy_candidates`, default 20, `Screener._filter_and_cap`): the screener
    ranks the admitted long candidates by score (alphabetical tiebreak) and returns the top 20 to the entry walk. Never
    swept as an axis (the 06-29 earliness grid moved the *ranking*, not the cap). Ranking has no skill
    (`project_entry_selection_closed_powered`, `project_cascade_selection_inversion`), so the cut at 20 is a lottery
    that drops 36 % of monsters — and it costs nothing to widen: per-position size (0.14), exposure (0.70), slots (20)
    and the grade floor are untouched, so a wider list only matters on weeks where > 20 names clear the gates and the
    entry walk still has cash. That is exactly the shape the fat-tail law wants tested (`project_edge_is_the_fat_tail`:
    "bias toward tail-preserving levers — breadth, entry quality"): fresh opportunities, not stale entries
    (`project_early_stage2_window_validated` WHY 2: entry-breadth ≠ universe-breadth — this arm is the *breadth* side).
- Regime framing the read must carry (`project_pit_drawdown_2021_25_macro_veto`): on the band, ≥ +20 % winners fell
  from 10 % of entries to 2 % after 2021-11. A wider list that adds 2022–25 entries adds losers unless the extra names
  are the ones that would have carried the tail — the mechanism read is by entry-year, not pooled.

## Arm + diagnostic (specs/, run by chain-funnel.sh from a pinned worktree `sweep-funnel` = main @ `ad5a9e04e`)

| cell | change vs `a0-pit-null` | pairs against | purpose |
|---|---|---|---|
| `t1-topn-40` × salts 0/1/2 | `((screening_config ((max_buy_candidates 40))))` — nothing else | committed `pit-universe-2026-09-14/step4/results/a0-pit-null-s{0,1,2}-v11-*` | the arm |
| `d0-funnel-diag` × salt 0 | **none** (config identical to the null); the chain passes `--emit-candidates` | same null, salt 0 | `candidates.sexp` = per-week cascade population + drop phase on the PIT band; `trades.csv` md5 must equal the committed null's (`c1352be681e2eea3bf50d5c58a94f8a7`, 733 lines) — the determinism tripwire *and* the proof that the diagnostic is observability-only |

The null is NOT re-run. Build drift between the null's build (3a20f4987, #2816) and `ad5a9e04e`: the veto experiment
already audited 3a20f4987 → 477522b7c as runtime-inert (its README §Arm) and its salts 1–2 reproduced the null's
2000→2018/2019 trades exactly; 477522b7c → ad5a9e04e adds #2884 (results only), #2885/#2890/#2892 (docs / ops) and
**#2888** (cache-occupancy telemetry, `Telemetry only, no behaviour change` — the d0 tripwire is the check). Same
warehouse (`/tmp/snap_top3000_pit_v11pit`, 9,364 entries — the chain aborts on any other count), same 27 composition
lists, `SNAPSHOT_MAX_MMAP_HANDLES=12000`, `CELL_TIMEOUT=60000` (≥ 1.5× the slowest measured arm cell on this build
class: 4h19m), one lane. Pairing gate: `validator_diff -check V6` exit 0 on every pair.

Order: **d0 first** (the null control before the arm — `feedback_run_the_null_control_first`; a MISMATCH stops the
lane, nothing else runs until the drift is explained), then t1 s0, s1, s2.

## Pre-registered decision rule

**The arm clears if realised P&L AND Calmar are both better than the null at ≥ 2 of 3 salts** (the 09-13 / 09-16
rule). MaxDD, Sharpe, level, trade count, exit mix, open-MTM and concurrent-name count are reported; level is not a
criterion. A clearing arm is an ACCEPT for the *mechanism* on this base; promotion to default-on still needs the grid
(`promotion-confirmation.md`: broad-vs-broad breadth tier + a period-disjoint cell) and the paired-golden table
(`config-default-blast-radius.md`). A failing arm is a REJECT-as-default; the knob stays an axis (it is a plain
capacity dial, never do-not-revive unless the read shows widening is *monotonically* stale, as `early_stage2` was).

**Mechanism read (the number this arm exists to produce):** `symbol|entry_date` join of arm vs null `trades.csv` per
salt → shared / null-only / arm-only. Arm-only entries are the candidates that ranked 21–40 and got funded (plus any
path divergence they cause — separate the two by first-divergence date). Report per entry-year: count, realised P&L,
≥ +20 % share, median hold — the arm clears *because of* fresh winners only if the arm-only cohort carries a tail
comparable to the shared cohort's; if the arm-only cohort is ≥ 80 % losers at every salt the widening is stale-entry
breadth in a capacity costume and the verdict is REJECT with that why. Also: weeks per year where the null's list was
exactly 20 (the cap bound) from d0's `candidates.sexp` (`Dropped_at_top_n` count > 0), so the arm's effect is scoped to
the weeks where the dial can act at all — if those are < 10 % of screening weeks the arm is expected inert and an
inert result is a finding (the 36 % monster share was a strong-tape phenomenon), not a failed run.

**From d0 alone (no verdict, a decomposition):** the PIT-band funnel by phase per year — `Dropped_at_breakout` sub-reason
partition (`Price_floor | Stage_setup | Breakout_volume | Rs_declining | Failed_breakout | Volume_band`),
`Dropped_at_top_n`, `Dropped_at_grade`, `Admitted` — and how many admitted names got no ticket. This is the 26y
decomposition `project_monster_funnel_top_of_funnel` said was "the #2490 follow-up's next step"; it replaces the smoke
read (94 % `Stage_setup`) with the real one.

## Cost / ops

~4 h per cell on the knob build (veto arm: 4h19m / 3h37m; the null 5h58m at cap 256 — never size the guard from it),
~16 h for d0 + three arm cells, one lane. Container-exclusive: no agent dispatches while a cell runs
(`container-capacity-scheduling.md` rule 1); QC on open PRs runs first (rule 0). Specs staged at
`/tmp/funnel-run/specs` (outside any VCS tree), artifacts at `/tmp/sweeps/top-of-funnel/` (bind-mounted), per-cell raw
artifacts committed to `results/` after each cell (`feedback_commit_raw_per_arm_artifacts`: never read a number from
the chain log; the summary line is scoped to `${out}/<name>/actual.sexp`). Each cell logs GNU-time peak RSS and the
`snapshot cache` line (`perf-review-weekly.md` rule 3).

## Log

- 2026-09-21 14:05 PT — pre-registered. Worktree `sweep-funnel` pinned at `ad5a9e04e` (= main); build + launch wait
  for the open QC wave (#2889 behavioral, #2894 structural/behavioral) to clear the container.
- 2026-09-21 13:25 PT — **lane A launched** (`EXPECT_HEAD=ad5a9e04e sh chain-funnel.sh A d0-funnel-diag:0:emit t1-topn-40:0
  t1-topn-40:1 t1-topn-40:2`, script + specs staged under `/tmp/funnel-run/`, artifacts `/tmp/sweeps/top-of-funnel/`,
  chain log `/tmp/funnel-run/chain-A.log`). Pre-registration merged as #2897 (CI + both QC gates, quality 5/5) before
  the first cell started; the perf-tier fix #2894 and the deps bump #2889 merged the same hour, so the container was
  idle at launch (326 MB). Reviewer advisory adopted: `candidates.sexp` is ~500 MB per cell and is NOT committed —
  `results/` gets the derived funnel decomposition (per-year counts by phase and sub-reason) plus the usual per-cell
  raw artifacts. `paired.sh` (this commit) is the per-salt read; columns pinned to the 09-21 `trades.csv` header.
- 2026-09-21 20:49 PT — **d0 done: tripwire MATCH** (md5 `c1352be6…`, 457.01 % / 732 trades, V6 = 0); wall 7h25m,
  peak RSS 7.60 GB (`--emit-candidates` ~doubles the cell; `candidates.sexp` 945 MB, kept in the container only).
  `results/d0-funnel-decomposition.md` + `d0-funnel-by-year.csv` (via `funnel.awk`): the top-N cap binds in
  99.1 % of weeks, ≥ 20 names cut in 96.3 %, and 33.8 A_plus names/week fall at the cap — the marginal 21–40 are
  score-tied with the admitted 20 (alphabetical tiebreak). Arm cells `t1-topn-40` s0/s1/s2 now running.
- 2026-09-22 01:38 PT — **t1-topn-40 s0 done** (4h48m, 6.47 GB, V6 = 0): **237.38 % / 771 trades / maxDD 44.48 / Calmar 0.106 vs
  null 457.01 / 732 / 40.64 / 0.165 — fails both metrics at this salt.** `results/t1-topn-40-s0-read.md`: arm-only 280
  trades −$0.87 M (68 % losers, 6.8 % ≥ +20 %), null-only 241 +$1.34 M; arm *ahead* through 2019 (+$752 k at 2017),
  loses the 2020 and 2025 monster cohorts (−$2.2 M by 2026). `join.awk` on d0's cascade: only 28 % of arm-only entries
  were the marginal 21–40; 46 % were names the null admitted too but never filled — slot/cash reshuffle, not capacity.
  s1 running (started 01:38 PT).
- 2026-09-22 05:54 PT — **t1-topn-40 s1 done** (4h16m, 6.46 GB, V6 = 0): **303.97 % / 748 / maxDD 43.84 / Calmar 0.123 vs
  null 188.05 / 766 / 53.05 / 0.077 — clears both at this salt; s2 decides.** `results/t1-topn-40-s1-read.md`: the
  mirror of s0 — arm-only 280 trades +$0.88 M of which ECHO 2025-08-26 is +$677 k (77 %); null-only 298 trades +$4 k
  (2018 and 2024 whipsaw cohorts, 42 losers of 56). Same cohort sizes, opposite sign: a slot re-draw. s2 running
  (started 05:54 PT, done ~10:10 PT).
- 2026-09-22 09:53 PT — **t1-topn-40 s2 done, LANE A DONE** (3h59m, 6.45 GB, V6 = 0): **329.51 % / 766 / maxDD 44.68 /
  Calmar 0.127 vs null 152.03 / 762 / 51.32 / 0.069 — clears both.** Rule: **2 of 3 → ACCEPT** (§Verdict below).
  `results/t1-topn-40-s2-read.md`. Chain log archived as `results/chain-A.log`; worktree and `/tmp/funnel-run`
  removed; `candidates.sexp` deleted (decomposition committed).

## Verdict (2026-09-22, pre-registered rule: realised AND Calmar better than the null at ≥ 2 of 3 salts)

| salt | null: return / maxDD / Calmar | arm (cap 40): return / maxDD / Calmar | realised | Calmar |
|---|---|---|---|---|
| s0 | 457.0 / 40.6 / 0.165 | 237.4 / 44.5 / 0.106 | fail (−220 pp) | fail |
| s1 | 188.0 / 53.0 / 0.077 | 304.0 / 43.8 / 0.123 | clear (+116 pp) | clear |
| s2 | 152.0 / 51.3 / 0.069 | 329.5 / 44.7 / 0.127 | clear (+177 pp) | clear |

**ACCEPT(mechanism) by the pre-registered rule — 2 of 3 salts clear both metrics.** Not promotable on this surface
alone (`experiment-flag-discipline.md` R3 + `promotion-confirmation.md`): one point of the knob (40) on one window and
one breadth tier. What the three salts actually support, and what they do not:

1. **The level is a salt lottery, on both sides.** Cohort sizes are the same at every salt (arm-only 280 / 280 / 265,
   null-only 241 / 298 / 261, ~36 % of each book) and the sign of the arm-only cohort flips: −$0.87 M / +$0.88 M /
   +$0.85 M, against null-only +$1.34 M / +$0.004 M / −$0.51 M. At s0 the null's draw holds the 2020 and 2025 monster
   cohorts; at s1 the arm's draw holds ECHO (+$677 k of its +$0.88 M); at s2 the arm's draw holds six $230 k+ winners.
   Never quote +177 pp or −220 pp as the mechanism (`project_clock52_promoted`: same rule for the 52-week clock).
2. **The robust property is dispersion, not level (n = 3, PLAUSIBLE).** Arm realised 237–330 % (range 93 pp) vs null
   152–457 % (305 pp); arm maxDD 43.8–44.7 (0.9 pt) vs null 40.6–53.0 (12.4 pt); arm Calmar 0.106–0.127 vs 0.069–0.165.
   Means: return 290 vs 266, Calmar 0.119 vs 0.104; medians 304 vs 188 and 0.123 vs 0.077. A 40-name list makes the
   book less dependent on which A_plus tie wins the slot. Three draws cannot separate "the arm is less path-dependent"
   from "the null's s0 is the outlier"; the confirmation grid is the test.
3. **Mechanism: the leak is slot policy, not screener capacity.** d0: the cap binds in 99.1 % of weeks and 33.8
   A_plus names/week fall at it, but the book fills only ~28 entries/yr into ~5 slots (concurrency 4.67–4.85 null vs
   5.00–5.03 arm). Joining s0's arm-only entries to the null's own cascade: 46 % were names the null had **admitted**
   the Friday before and never filled, 28 % were the marginal ranks 21–40, 25 % older resting orders. Widening the list
   re-draws which resting orders trigger first against the slots and the cash floor; the marginal names themselves are
   slightly worse (score 102–103 vs 106–107 for null-only; winner rate 6.8 / 8.6 / 9.1 % vs 10.8 / 7.7 / 6.9 %, no
   robust sign). #2490's "36 % of monsters die at top-N" is therefore mostly a **slot** loss: the monster was screened;
   it did not win the slot that week.
4. **Universe / basis:** every cell on the 27-entry yearly top-3000 PIT schedule, `_v11pit`, V6 = 0 at every salt,
   d0 tripwire byte-identical to the committed null s0 — same build, same inputs, same fill model as the record band.

**Classification:** ACCEPT(mechanism), keep default-off (`max_buy_candidates` stays 20) as an axis. **Promotion path**
(if anyone wants it): confirmation grid per `promotion-confirmation.md` — (a) the surface {30, 40, 60} not one point,
(b) a disjoint sub-window (2019–2025) on the same schedule, (c) a top-1000 schedule cell; promote only if the
dispersion property (tighter maxDD band, median ≥ null) holds in ≥ 2 of 3 cells. Level gains are not the criterion.

**Forward guidance (the transferable why):** the top of the funnel is not capacity-bound at the screener; it is
capacity-bound at the slots. The next lever is **slot policy** — what fills first when the admitted list exceeds the
open slots (today: whichever resting order triggers first, alphabetical among score ties), and whether a
higher-conviction ordering (score, then RS, then volume ratio, never alphabetical) changes the fill set in a way that
is robust across salts. That is a screener-ordering dial the book supports (RS for selection, spine item 7), cheap to
pre-register, and it attacks the same ~36 % of each book that this arm merely re-shuffled. Not another cap-width point.

**Runtime (perf-review-weekly §3):** arm cells 4h48m / 4h16m / 3h59m at cap 12,000 (peak RSS 6.45–6.47 GB); the
60,000 s guard was 3.5× the slowest cell. `--emit-candidates` doubled d0 (7h25m, 7.60 GB) — keep it off verdict cells.
