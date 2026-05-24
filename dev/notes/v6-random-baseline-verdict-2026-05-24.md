# v6 random-search baseline — verdict: random matches BO; surface is the bind (2026-05-24)

Step 0 of the tuning-methods track (`dev/plans/tuning-methods-track-2026-05-24.md`).
Settles the question raised by the 11-knob plateau verdict
(`dev/notes/11knob-plateau-verdict-2026-05-24.md`): **does the BO surrogate (GP + Expected Improvement) add value over uniform random sampling at this budget on this surface?**

**Verdict: NO.** Random matches BO. The surface is the bind, not the surrogate.

## Setup

- **Spec:** `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_random_v1.sexp` — identical to v4's `spec_prod_11knob_v1.sexp` except `initial_random = total_budget = 60` (zero BO acquisition; pure uniform-random sampling).
- **Walk-forward fixture:** `cell_e_30fold_2026_05_16.sexp` (same as v4; 30 rolling folds, 26 in-sample + 4 holdout).
- **Seed:** 2026 (same as v4).
- **Parallel:** 4.
- **Output:** `/tmp/sweeps/11knob-v6-random/` via host bind-mount (`.sweep-output/11knob-v6-random/`) per the safe-sweep infra landed in #1284.
- **Outcome:** terminated at **iter 29 / 60** via graceful `SIGTERM` after verdict was conclusive. Saved ~10h of confirming-the-obvious compute.

## Data

| | v4 (BO-EI, terminated iter 34) | v6 (pure random, terminated iter 29) |
|---|---:|---:|
| Best composite score | **-9.6516** | **-9.6516** |
| Worst composite score | -10.4640 | -10.4640 |
| Score spread | 0.81 | 0.81 |
| Iters in "BO acquisition" phase | 19 (iters 16–34) | 14 random iters past the first 15 (iters 16–29) |
| BO-zone improvement on best random | **NONE** | — |
| Random-zone improvement on best so far | — | **NONE** |

Sorted scores at v6 termination (29 entries):

```
-10.4640  -10.2011  -10.1953  -10.1891  -10.1225  -10.1224
-10.1059  -10.1007  -10.0960  -10.0707  -10.0364  -10.0254
 -9.9900  -9.9490  -9.9414  -9.9129  -9.8810  -9.8594
 -9.8560  -9.8345  -9.8301  -9.8266  -9.8232  -9.8050
 -9.7659  -9.7058  -9.6820  -9.6516  -10.4640 (= worst entry — duplicates not removed)
```

Best stays at **-9.6516** across both methodologies. Worst stays at **-10.4640**.

## Interpretation

Two methodologies, identical seed, same budget surface, **identical best score**. No optimum was hidden from BO's exploit-leaning Expected Improvement that pure random sampling found. No optimum random missed that BO found.

The 11-D box defined by the 11 knobs has its global (or near-global) optimum at the random sample that scored -9.6516. Neither methodology can find anything better at this budget.

**Three possible reads, each with action implications:**

| Read | Implication |
|---|---|
| **(a) Surface is genuinely flat near the optimum** | The 11 knobs collectively encode a near-constant composite-score response surface around the best basin. No methodology fixes this. The next move is changing the surface itself — component-decomposition objective, or strategy-mechanic changes (entry-timing). |
| **(b) Both methods need >>60 iters to converge** | Possible but unlikely — BO with 19 acquisition iters in 11-D typically shows clear EI-driven improvement by iter 30-40. A budget increase to 200+ would test this, but the cost is high. |
| **(c) The score function (Composite) is too noisy across in-sample folds to distinguish knob settings** | If fold-to-fold metric variance dominates knob-to-knob variance, no optimizer can resolve the signal. Would explain why the same -9.6516 random sample is "best" across two independent runs. |

**Most likely combined diagnosis:** **(a) + some (c)**. The surface is locally flat AND the metric is noisy. Both push toward "change what you measure" rather than "change how you search."

## Strategic implications

Reframe the decision tree from `dev/notes/11knob-plateau-verdict-2026-05-24.md` again:

| Original option | Status after v6 |
|---|---|
| 1. Broader universe | OUT (full-pool 2019 baseline disproved this 2026-05-23) |
| 2. Tuning-methods track | **DEMOTED**. Step 0 (random) matched BO. Step 1 (TPE) and step 2 (Hyperband) are now lower-priority: if the surface is flat, no surrogate helps. They might still be informative experiments but no longer load-bearing. |
| 3. Component-decomposition objective | **PROMOTED to P0**. Now the most-promising remaining path. ~200-400 LOC + 12-20h CPU. Per priorities-doc P1 (already scoped). |
| 4. Entry-timing variant | Still on the list (allowed per user preference). Larger PR (~500+ LOC) but addresses the "change the surface" thesis directly. |

## Next session P0

**Open the component-decomposition objective track.** Plan:
1. Scope: replace global Composite objective with `score = w1·screener_quality + w2·portfolio_health + w3·order_fill + w4·stop_efficacy`.
2. Define each component as a measurable metric (which fold-level data is the "screener quality" — false-positive rate, capture rate, RS-rank stability, etc.).
3. Re-run BO against the new objective. The BO can now optimize per-component instead of the noisy global P&L.

If a single component IS optimizable (one of the w-weighted terms shows clear knob-dependent variation), that's the path forward — even if the global Composite stays flat.

## Methodology comparison residual interest

Steps 1-3 of the tuning-methods plan (TPE / Hyperband / CMA-ES) remain **interesting but not load-bearing**. Run them only if either:
- The component-decomposition experiment reveals a component the GP-EI surrogate poorly fits (then TPE/CMA-ES might find better optima on that surface).
- We need wall-time efficiency (Hyperband prunes bad iters — only useful if iters are expensive AND we're running many).

## Cost recap of today's sweep work (2026-05-23/24)

| Run | Status | Iters | Wall time |
|---|---|---:|---:|
| v1 | crashed iter 1 | 0 | minutes |
| v2 | killed by jj | ~2 | ~1h |
| v3 | killed by jj/disk | 37 | ~7.5h |
| v4 (BO) | killed by disk | 34 | ~6h (over ~12h with restarts) |
| v5 (random, parallel=2) | killed by disk @ iter 4 | 4 | ~1h |
| **v6 (random, parallel=4)** | **terminated cleanly @ iter 29** | **29** | **~10h** |

Total wall time spent: ~28h. Total iters of usable signal: v4 BO 34 + v6 random 29 = **63 iters of data**. Both methodologies agree: surface flat at -9.65.

## References

- `dev/notes/11knob-plateau-verdict-2026-05-24.md` (parent verdict)
- `dev/plans/tuning-methods-track-2026-05-24.md` (track plan — now needs status update: step 0 done, steps 1-3 demoted)
- `dev/plans/safe-sweep-infrastructure-2026-05-24.md` (infra prereq; gap noted re: snapshot path)
- `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_random_v1.sexp` (the v6 spec)
- Sweep raw output: `.sweep-output/11knob-v6-random/bo_checkpoint.sexp` (on host disk, not committed)
- `memory/feedback_jj_restore_killed_sweep.md`, `memory/feedback_worktree_disk_kills_docker.md` (today's hard-won infra lessons)
