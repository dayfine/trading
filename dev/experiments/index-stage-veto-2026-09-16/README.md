# Index-stage veto on the PIT band — P0 #1 of the 09-17 queue (2026-09-16)

**Status: PRE-REGISTERED** (written 17:10 PT 2026-09-16, before the mechanism merged and before any cell ran). One arm,
three salts, paired against the committed PIT record null.

## Why

- `pit-universe-2026-09-14/README.md` §"Drawdown dissection": the band's NAV is one episode (late-2021 peak → 2024/25
  trough, −38..−53 % on every arm). The largest universe-independent mechanism found is that **`Macro.analyze`'s composite
  outvotes a Stage-4 primary index**: in 2022 SPX closed below a falling 30-week MA from 01-21 through November, yet the
  weekly `trend` read Bullish for 25+ weeks (index-stage weight 3.0 vs 7.0 of breadth-type gauges; `confidence > 0.65`).
  126 entries in 2022 (103–117 per salt under a Bullish label), 82 % losers, median hold 15 d vs 37, −$0.8M per salt.
- Book check (tier 2, local, 2026-09-16; written back to `docs/design/weinstein-book-reference.md` §2.1 "Resolved
  2026-09-16", PR #2861): the index's Stage-4 breakdown is an explicit, unconditional suspension of new buying — Ch. 8
  "Stage Analysis for the Market Averages", "Suspend buying even if you see a few stocks breaking out on their charts".
  Stage 3 is caution only. So the veto is a **faithful dial** (`weinstein-faithful-core.md` W2, tightening spine item 6),
  not an invented mechanism.
- Standing priors this arm must respect: `project_edge_is_the_fat_tail` (a gate that also blocks the 2009 / 2003 / 2020
  re-entries can lose more than the 2022 cohort it saves — hence the per-episode read below);
  `project_deteriorating_gate_reject` (a regime label on admission was anti-predictive — but that label was a breadth
  composite; this one is the book's primary gauge, and the 2022 cohort is where the composite and the index disagreed).

## Mechanism (lands first, default-off — `experiment-flag-discipline.md` R1/R2)

`index_stage_veto_blocks_longs : bool [@sexp.default false]` on `Weinstein_strategy.config` (PR: feat/index-stage-veto,
branch of 2026-09-16). A pure extra conjunct on the long admission gate — fresh candidates via `screening_config` and the
F2 resting-ticket re-screen, exactly like `deteriorating_blocks_longs` (#2755) — that rejects longs while
`Macro.result.index_stage.stage = Stage4 _`. `trend`, shorts, halts, the macro-bearish trim and `breadth_state` are
untouched: the composite keeps governing aggressiveness. Default-off is bit-identical (goldens unchanged, CI).

## Arm (specs/, run by chain-veto.sh from a pinned worktree `sweep-veto` built off main after the flag merged)

| arm | change vs `a0-pit-null` | pairs against |
|---|---|---|
| `v1-index-veto` | `((index_stage_veto_blocks_longs true))` — nothing else | committed `pit-universe-2026-09-14/step4/results/a0-pit-null-s{0,1,2}-v11-*` |

The null is NOT re-run (6.3 h/cell). Build drift between the null's build (3a20f4987) and the arm's is runtime-inert by
inspection: 11 commits under `trading/` — harness / orchestrator / codex fixes (#2852 #2855 #2842 #2841 #2834 #2836
#2830 #2821), the scheduled smoke golden #2846 (CI-only, its golden re-pinned bit-identical), the record artifacts #2843,
and the trade-audit R7 pin #2813 (reporting only) — plus the veto PR itself, whose default-off path is bit-identical.
Same warehouse (`/tmp/snap_top3000_pit_v11pit`, 9,364 entries — the chain aborts on any other count), same 27 as-run
composition lists, same `CELL_TIMEOUT=36000`, one lane. Pairing gate: `validator_diff -check V6` exit 0 on every pair
(the chain runs it per cell against the committed null report; V6 = 0 on every null salt).

## Pre-registered decision rule

**The arm clears if realised P&L AND Calmar are both better than the null at ≥ 2 of 3 salts** (same rule as the 09-13
concentration probe). MaxDD, Sharpe, level, trade count, exit mix and open-MTM are reported; level is not a criterion
(the null's salt-0 level is a salt-lottery top). A clearing arm is an ACCEPT for the *mechanism* on this base; promotion
to default-on still needs the grid (`promotion-confirmation.md`: broad-vs-broad breadth tier + a period-disjoint cell)
and the paired-golden table (`config-default-blast-radius.md`). A failing arm is a REJECT-as-default; the flag stays an
axis unless the mechanism read says do-not-revive.

**Mechanism read (the number this arm exists to produce):** `symbol|entry_date` join of the arm's and null's
`trades.csv` per salt → shared / null-only / arm-only, then the **2022 entry cohort** (null: 126 entries pooled, 82 %
losers, −$2.43M): how many of those entries the veto removed, their P&L, and what the freed cash bought instead
(arm-only entries dated 2022–23 and their P&L). Per entry-year realised for both arms.

**Re-entry cost, read per episode so a 2022 win is not bought with a slower recovery:** paired entries and P&L for
2003 (post dot-com Stage-1 → 2 turn), 2009 (post-GFC), 2020 (COVID V) and 2022–23 — the four windows where the index
leaves Stage 4. If the veto removes the 2009 / 2020 re-entry cohort's winners, that is the fat-tail tax
(`project_edge_is_the_fat_tail`) and the arm is not promotable even if 2022 clears. Also: number of screening weeks per
salt on which the veto fired while `trend` was Bullish/Neutral (the composite-vs-index disagreement weeks), from
`macro_trend.sexp` + the SPX weekly stage (the arm's `trade_audit.sexp` records the rejection reason where available).

## Cost / ops

~6.3 h per cell, one lane (single worker sits at 5.5–6.5 GB); ~19 h for the arm. Container-exclusive: no agent
dispatches while a cell runs (`container-capacity-scheduling.md` rule 1). Specs staged at `/tmp/veto-run/specs`
(outside any VCS tree), artifacts at `/tmp/sweeps/index-veto/` (bind-mounted), per-cell raw artifacts committed to
`results/` after each cell (`feedback_commit_raw_per_arm_artifacts`: never read a number from the chain log).

## Log

(cells append here as they finish)
