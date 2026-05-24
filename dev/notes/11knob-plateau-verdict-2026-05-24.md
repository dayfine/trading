# 11-knob BO sweep — plateau verdict (2026-05-24)

Settles the strategic question raised by the 2026-05-15 pivot
(`memory/project_strategic_pivot_broader_first.md`): does adding 7 more
knobs on top of V3's 4-knob surface escape the plateau?

**Verdict: no. 11-knob surface plateaus at the same place as 4-knob V3.**

## Data

### v4 (BO with 11-knob spec) — partial, 34/60 iters

Spec: `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_v1.sexp`
(restored 2026-05-23 via #1267 after the int-knob plumbing landed in
#1258 + #1261). Walk-forward fixture:
`trading/test_data/walk_forward/cell_e_30fold_2026_05_16.sexp` (30
rolling 1-year folds on `goldens-sp500-historical/sp500-2010-2026.sexp`,
26 in-sample + 4 holdout).

Sweep ran 2026-05-23 → 2026-05-24 across 4 attempts (v1 crashed at iter 1
on int-knob plumbing; v2/v3 killed by jj-restore / disk-fill chain;
v4 was the surviving attempt). v4 got to **34 iters** before Docker
ran out of disk and was killed during the session's disk recovery.

At iter 34 the picture was already clear:

| | Score |
|---|---:|
| Best (iter ≤15 random sample) | **−9.6516** |
| Worst (iter ≤15 random sample) | −10.4640 |
| Spread | 0.81 |

**19 BO acquisition iters (iters 16–34) never beat the best random
sample.** Acquisition iters filled the middle band (−9.7 to −10.2);
none extended the best or worst.

Sister-run v5 random-search baseline (`initial_random=60, total_budget=60`,
zero BO acquisition) was launched as a control but also lost to the
disk-fill chain after ~4 iters. Per-iter scores within the 4 completed
random iters already included −9.6516 — same population as v4's random
samples, completion order differs under parallel fork-pool.

### Full-pool 2019 baseline (companion experiment, #1281)

Settled the broader-universe hypothesis: would a wider universe lift
the plateau? Cell-E run on the full `top-3000-2019.sexp` (~2,549
sector-tagged names, no random subsampling) for 2019-2023:

| Universe | Return | Sharpe | MaxDD | Trades |
|---|---:|---:|---:|---:|
| top-500-2019 (size-weighted) | +78.34% | 0.69 | 42.17% | 263 |
| sp500-2019-2023 | +50.66% | 0.56 | 21.56% | 264 |
| **full-pool top-3000-2019** | **+32.37%** | **0.37** | **32.48%** | **278** |

**Going from top-500 → full pool drops return by 46pp and Sharpe by
~half (0.69 → 0.37).** Decomposition: ~30% of the top-500 premium is
"size-weighted universe is richer"; ~70% is genuine survivor bias
(2019 mega-caps that survived to 2026). Trade count clusters tightly
(263–278) across all three universes — **strategy is position-cap-
bound, not universe-bound**. Wider universes dilute returns via
marginal names that fail more often.

The "broader universe lifts the plateau" hypothesis is **disproved**.
Broader universe is a Sharpe-degrader for this strategy at current
config.

## Reframed strategic decision tree

Original decision tree (from `dev/notes/next-session-priorities-2026-05-23.md`
+ the 2026-05-15 strategic pivot) had 4 options after a 11-knob
plateau. Two are now eliminated:

| Option | Status | Reason |
|---|---|---|
| 1. Broader universe (rolling-PIT) | **OUT** | Full-pool 2019 baseline shows broader = lower Sharpe; not the unblock |
| 2. Tuning-methods track | **IN** | Random-search baseline + TPE + Hyperband comparison. New track scoped in `dev/plans/tuning-methods-track-2026-05-24.md`. |
| 3. Component-decomposition objective | **IN** | Per priorities-doc P1 — BO targets weak component (screener / portfolio / order / stop) instead of global P&L. ~200-400 LOC + 12-20h CPU. |
| 4. Entry-timing variant | **IN** | The one allowed M8+ mechanic change per user preference (`memory/feedback_strategy_mechanic_changes_too_explorative.md`). |
| ~~4'. Other M8+ mechanic changes~~ | OFF | Stop redesigns / continuation overhauls / Kelly sizing — too explorative without specific evidence. |

## Sequencing for next session

P0 — **launch the tuning-methods track**. First experiment: random-search
baseline at budget=60, same spec/seed as v4. Tells us whether the BO
surrogate is even adding value at this budget. If random ≥ BO best,
the bind is the surface, not the optimizer.

P1 — TPE / Hyperband ports. Open-track work.

P2 — Component-decomposition objective design.

P3 (parallel) — Entry-timing variant scoping.

**PREREQUISITE for any sweep:** the safe-sweep infra plan
(`dev/plans/safe-sweep-infrastructure-2026-05-24.md`) must land FIRST
— today's session lost ~16 hours of sweep wall-time across v2/v3/v4/v5
to disk-fill and jj-restore disasters. Don't re-launch sweeps under
the same risk profile.

## References

- `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_v1.sexp`
- `trading/test_data/walk_forward/cell_e_30fold_2026_05_16.sexp`
- PR #1281 — full-pool 2019 baseline run + comparison doc
- `dev/notes/full-2019-pool-baseline-2026-05-23.md`
- `memory/project_strategic_pivot_broader_first.md` (2026-05-15)
- `memory/feedback_strategy_mechanic_changes_too_explorative.md`
- `memory/feedback_jj_restore_killed_sweep.md`
- `memory/feedback_worktree_disk_kills_docker.md`
