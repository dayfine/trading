# Next-session priorities — 2026-09-04 (post D1/D2 default-flip session 09-03)

Supersedes `next-session-priorities-2026-09-03.md`. Its P0 is DONE (below);
its two P1s are half-done (splice detection shipped; vintage warehouses not
started); P2 carries.

## What landed (all merged unless marked)

- **#2648 — D1/D2 exit-basis default flip** (`sim_exit_fill_next_open`,
  `stops_config.stop_skip_entry_bar` → `true`). Three commits: the flip
  (`398f57111`, runtest panel goldens regenerated, ledger entry
  `2026-09-03-exit-basis-d1d2-correctness` verdict Inconclusive = human-gated
  R3 override), the paired goldens (`d0806bcf`: 27 cells run PAIRED at the
  flip build in pinned worktree `sweep-d1d2`; 14 goldens re-pinned ±15% around
  the new-arm actual, return ≥ ±5pp; 13 wide-band sentinel cells kept;
  `dev/experiments/exit-basis-flip-2026-09-03/`), and QC rework 1
  (`66fcae44`: R1-style default pins + a bool `.mli` drift guard). **Merged** as `b3cac3672` after both QC gates APPROVED at the rework tip (the 05:17 orchestrator slot ran an independent behavioral review that agreed).
- **#2649 — V15 + `Splice_detector`** (#2646 asks 1–2): post-run check
  V15 (|pnl%| > 100 ∧ days_held ≤ 5 ∧ adj-close ratio ∉ [0.4, 2.5] on the
  entry/exit bar) and the default-off build-time gate (`-detect-splices`,
  writes `splices.csv`, drops nothing). `daily_bar` gained `adjusted_close`.
  One QC rework pinned the adjusted-vs-raw basis by mutation.
- **#2637** — csv-snapshot cleanup test flake root-caused (OUnit2 forks 2
  shards; the aggressive orphan sweep saw a sibling's live fixture).
- **#2650 filed** — tier-2 (goldens-small) and tier-4 (goldens-broad) pins
  were stale since the 08-24/08-26 flips; `perf-nightly` `continue-on-error`
  hid it. Fixed by the #2648 re-pins; the asks are about the gate.

## What the paired goldens said (read before any exit-lever claim)

19 of 27 cells moved down, 7 up, 1 flat. **Shared-trade drift is small and
mixed-sign** (−$314k over 396 shared trades on sp500-2010-2026; +$79k over
143 on six-year). **Every large level gap is a missed or gained monster
after the two books diverged**: top-500 composition 475% → 41% is GME
(+$4.76M, screened six times but never funded on the fixed basis);
sp500-2010-2026 −153pp is KLAC 2025 (+$1.04M); tier-4 six-year −97pp is the
2020 MSTR/BBWI cluster. maxDD unchanged within a few pp except where the
missed monster also removed its drawdown. **No return claim attaches to the
flip.** Memories: `project_top500_composition_golden_is_gme`,
`project_lever_reads_invert_on_fixed_sim`.

## P0 — re-measure the exit levers on the fixed basis

**Progress 2026-09-03 evening.** Two of the suspect reads are now re-measured
(`dev/experiments/stop-anchor-rebase-2026-09-03/`): (1) `stop_anchor_at_entry_base`
— the old salt-robust +60pp was ONE admission (DDS 2020-10-05, in every
anchor-on arm at every salt, absent from every anchor-off arm) plus the D2
artifact killing it at narrow widths; ex-DDS the anchor is sign-indeterminate
across salts (−$37k / +$74k / +$298k, a spread 3× the null's own) → REJECT as
promotion candidate, keep as axis; at buffer 0.885 (≈15%) on and off are
bit-identical, pinning the gate mechanism. (2) `initial_stop_buffer
0.98` (≈5.9% fallback, anchor off) beats the null 3/3 salts on 2019–23 with
shared-trade drift ≈ 0 and no shared monster — the edge is the null's extra
4%-stop whipsaw deaths (19 / 31 / 26 more stops per salt); at salt 2 one
null-only loser (STMP −$166k) is half the delta, and ex-STMP it still wins 3/3
(+$155k / +$76k / +$175k). **The first fixed-basis lever candidate whose edge is
not a single admitted monster** on that base. Its surface on the RECORD convention
(`dev/experiments/stop-width-surface-2026-09-03/`, 2019–23 + 2000–04 × salts {0,1,2}
+ 26y) came back **regime-dependent**: 2000–04 wins 3/3 salts ex-monster with
positive shared-trade drift (+$78–87k) and better maxDD at two of three salts
(−7.8 / +1.0 / −7.7pp); 2019–23 loses 3/3
ex-monster (its raw +46pp is MSTR, wide-arm-only at every salt) with ~10pp worse
maxDD. Pre-registered rule not met → **keep `initial_stop_buffer 1.0` as default;
0.98 is a trader-mode / regime dial**, not a promotion candidate
(`project_stop_width_regime_dependent`). The recurring shape across every lever
re-measured today: the structural footprint is consistent, the level is set by
which monster a slightly different book funds — read shared-trade drift and the
ex-monster delta per salt, never the raw return.


Every pre-09-03 exit-lever verdict (eject on/off, stop width, TTL/clock,
laggard timing, the #2408 stop-anchor read) was measured on the defective
simulator. Re-run them as surfaces on the new default (no flags needed now)
— 1y/3y/5y broad windows first per the user (09-02), 26y confirmation only.
Start with the two the arc program most depends on: the §4.2 fill-week eject
gate and the fallback-stop width. The re-pinned goldens are the null.

## P1 — canonical record baseline on the fixed basis — DONE 2026-09-03

`dev/experiments/record-rebase-2026-09-03/`: the record convention PAIRED at
`e4984c5fe`. **New canonical record = 302.65% / 723 trades / Sharpe 0.397 /
MaxDD 36.26** (`results/rec26y-new-s0-*`, params committed). The paired old arm
(312.74) equals the 08-27 clock cell-A null digit-for-digit, so the 08-24
731.64% figure was the #2561 (v2 of #2555) RS-trend build delta; the exit basis costs −10pp, and on shared
trades it is a wash (stop tax −$565k vs D2-saved monsters +$814k). Mechanism
read in `project_d1d2_mechanism_decomposition`: D1 ≈ −1pp per stop exit on the 5y cells (−0.5pp at 26y); D2 removes the
entry-bar stop-outs (10–21% of an arm's trades; 8–16% survive as the same
entry), most of which re-stop within days, and a few become monsters (WNC
+160%, UGP +69%). Every writeup after today diffs against
rec26y-new.

## P1 — vintage warehouses (carried)

Warehouse = 2000 vintage (94% of top-3000-2000, 32% of top-3000-2019). Build
2009 and 2019 vintages before any level claim on a post-2005 window
(`project_warehouse_vintage_coverage`). Also: re-run the g00 / 2004-window
arc results ex-CHS (#2646 ask 3) now that V15 flags them.

## P2 — carried

- #2650: widen `goldens_affected_check.sh` to tier-2/tier-4 goldens or state
  they are out of scope; graduate `perf-nightly` from `continue-on-error`.
- Arc structural deficit (D3/D5): entry-side levers (weekly-close trigger,
  base-top anchor) on 1y/3y/5y broad.
- V15 follow-up from the #2649 review: the weekly-close bullets of
  `bars_of_daily`'s docstring are unpinned (P4/P5 probes stayed green).

## Ops notes from this session

- A QC agent's `gh pr checkout` moved the PARENT repo's git HEAD; jj imported
  it and re-parented `@`, reverting the flip sources on disk. Recovery was
  `jj rebase -r @ -d <flip>`. Every brief now says: `git fetch origin
  pull/N/head && git checkout --detach FETCH_HEAD` from inside the worktree,
  never `gh pr checkout` (`feedback_agent_gh_pr_checkout_moved_parent_head`).
- `TaskStop` does not kill the container-side dune; an orphaned runtest held
  the parent `_build/.lock` and wedged the next build for 10 min. Kill live
  `dune` PIDs in the container before relaunching; run long dune steps
  detached with file logs.
- Golden cells are much faster than the tier rationales say: 26y sp500 cells
  ~7 min, top-3000 26y ~10 min, top-3000 10y ~6 min, all on the committed
  CSV store with `--no-emit-all-eligible` (the all-eligible scan, not the
  backtest, was the multi-hour cost).
- Pinned worktree `.claude/worktrees/sweep-d1d2` can be removed once #2648
  is merged (`git worktree remove --force`).

## Do not

- Do not compare any post-09-03 number to a pre-09-03 one without pinning
  both knobs to the same value; the basis changed.
- Do not quote the top-500 composition cell's level as evidence (GME
  lottery), nor any g19 level as "broad".
- Do not cite pre-09-03 exit-lever verdicts without re-measuring.
