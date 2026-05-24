# Next-session priorities (2026-05-25)

> **SUPERSEDED in part 2026-05-25 PM by
> `dev/plans/tuning-research-driven-program-2026-05-25.md`.** A
> literature triage of frontier BBO methods (Hvarfner ICML 2024,
> Schneider/Bischl AutoML 2025, Daulton qNEHVI, López de Prado DSR)
> arrived at a tighter program that subsumes the P0a/b/c items below.
> The plan doc has the new 3-PR program + a comprehensive
> option-comparison table. This doc is retained for history of the
> reasoning path.

Supersedes `dev/notes/next-session-priorities-2026-05-23.md` and revises
parts of `dev/notes/v6-random-baseline-verdict-2026-05-24.md` based on
two user critiques after the v6 verdict landed.

## Two critiques that reshape what we should do

### Critique 1 — The fold-gate penalty is binary, not graded.

From `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.ml:46-48`:

```ocaml
let _compute_gate_penalty ~(value : float)
    (verdict : Walk_forward.Fold_gate.verdict) : float =
  match verdict with Pass _ -> 0.0 | Fail _ -> value   (* hardcoded 10.0 *)
```

A candidate that fails the gate by 1 fold (16/30 vs. 17/30 required) gets
the **same -10 penalty** as one that fails by 30/30. The optimization
surface is therefore discontinuous: a thin "Pass" cliff at the gate
boundary, surrounded by a vast flat -10 plateau everywhere else. Both
BO-EI and random-search see the plateau and never get gradients toward
the cliff because nothing distinguishes "almost passing" from "abysmally
failing."

The v6 best of -9.6516 = composite_delta ≈ +0.35 (candidate marginally
beats baseline on the weighted metric blend) minus the flat -10 penalty.
**Most candidates are within touching distance of the gate boundary** —
the optimizer just can't see it.

### Critique 2 — The training surface is overfit to Cell E.

Cell E wasn't designed top-down; it was iteratively tuned by humans over
months against the SP500 2010-2026 fold spec. The BO setup then defines
the acceptance gate as "candidate must beat Cell E in ≥17/30 folds on
**the same fold spec.**" The optimization is therefore comparing
candidates against a config already locally-optimized for this exact
data via gradient-of-human-attention.

The "plateau" verdict — random ≈ BO, both fail to find better — is
self-fulfilling. Cell E IS the local maximum on this surface. No 11-knob
direction is meaningfully better because Cell E was iterated to BE the
local max.

This invalidates parts of the v6-verdict framing:

| v6-verdict claim | Honest revision |
|---|---|
| "Surface is genuinely flat" | Surface is flat **around Cell E**, which was tuned to this exact data. Says nothing about whether the strategy class has slack elsewhere. |
| "Surrogate-change won't help" | True on this surface; untested on any Cell-E-never-saw surface. |
| "Component-decomposition is next P0" | Component-decomposition can help **regardless** — even on the same surface, per-component scoring reveals what's actually moving. But it's no longer the only P0. |

## The 3 P0 items (each independently valuable; sequenceable)

### P0a — Soft / continuous fold-gate penalty (small, immediate win)

**Why first:** cheapest of the three, unblocks both other items by giving
the optimizer a navigable surface. ~50 LOC change.

**The change requires both a functional-form decision AND a calibration
step. Don't ship without doing both.**

### Functional form (pick one — these are NOT pre-decided)

Three candidates, ordered by my preference:

1. **Cumulative per-fold Sharpe shortfall** (dimensionally natural, no
   coefficients to pick):

   ```ocaml
   (* For each fold the candidate lost, sum the Sharpe deficit. *)
   penalty = Σ_{f : fold} max 0.0 (baseline_sharpe_f -. candidate_sharpe_f)
   ```

   Pros: no arbitrary constants; the penalty IS the cumulative shortfall in
   the metric units the gate already cares about. Auto-scales: barely
   failing → small penalty; catastrophically failing → large penalty.

   Cons: requires per-fold data passed through to the scoring function.
   Need to verify `Walk_forward.Fold_gate.verdict` carries enough info.

2. **Two-term linear** (mixes count + worst-fold):

   ```ocaml
   penalty = w_m *. m_gap +. w_d *. delta_gap
   ```

   Requires picking `w_m` and `w_d`. **These are calibration-only constants;
   do NOT pick from gut feel.** Calibration procedure below.

3. **Smooth (sigmoid) around the gate boundary**:

   ```ocaml
   penalty = 10.0 *. sigmoid (alpha *. (required_m -. actual_m))
   ```

   Pros: smoothly differentiable; pass/fail boundary is a slope rather
   than a cliff. Cons: same calibration problem, plus one more
   constant (alpha) to pick.

**Recommendation:** form (1). No coefficient tuning required; the formula
is the dimensionally-natural thing.

### Calibration (mandatory regardless of form)

Inputs already on disk:
- v4 BO checkpoint: `/tmp/sweeps/11knob-v4/bo_checkpoint.sexp` (34 evaluations)
- v6 random checkpoint: `.sweep-output/11knob-v6-random/bo_checkpoint.sexp` (29 evaluations)

Total 63 evaluations with full per-fold metrics. For each, extract:
- m_gap (folds short of gate)
- delta_gap (worst-fold Sharpe excess below threshold)
- per-fold Sharpe shortfall sum (for form 1)
- old binary -10 penalty
- composite_delta (the un-penalized weighted-blend metric)

Then:
1. Re-score all 63 with the new penalty function.
2. Plot / tabulate the new score distribution. **Pass criterion: visible
   structure (spread > 5× the old 0.81 = 4+ score units).**
3. Verify ordering: candidates that v4 BO acquisition iterated toward
   should now score better than v4's random-sample misses (because BO
   was approaching the gate boundary).
4. Verify the relative ordering of the v4 BO best (-9.6516) vs random
   best is preserved (or both improve roughly equally).

If form 1 produces a flat surface → the per-fold-Sharpe signal IS noise
and even continuous-penalty doesn't help. That's itself a meaningful
finding (the noise-dominates-knobs hypothesis from the v6 verdict).

If form 1 produces visible structure → ship it. The optimizer now has
gradient toward Pass.

**Test plan:**

- Unit test: gate-verdict fixtures with various `actual_m` / `required_m` /
  per-fold Sharpe arrays; assert continuous penalty mapping.
- Re-score the existing v4/v6 BO checkpoints with the new penalty (pure
  function of stored data, no re-run needed). Surface should have
  spread > 5× the old 0.81 between best + worst.

**Effort:** ~50 LOC impl + ~80 LOC tests + ~30 LOC re-score script. 1 small PR.

### P0b — Cell-E-never-saw out-of-sample experiment

**Why second:** settles the meta-overfit question (Critique 2). If
candidates still match Cell E on a never-trained-on surface, the
strategy class is the bind, not the tuning. If a candidate clearly
exceeds Cell E on new data, today's "plateau" is just an artifact of
re-running BO against the same surface Cell E was iterated on.

**Concrete experiment:**

- **Walk-forward fixture:** new spec covering **1998-2009** (pre-Cell-E-tuning era) on the **top-3000-by-dollar-volume custom-universe** snapshots (`trading/test_data/goldens-custom-universe/composition/top-3000-YYYY.sexp` for YYYY in 1998..2009). That's 11 years × broader universe; **none of which Cell E was tuned on.**
- **Caveat:** survivor bias in the top-3000-YYYY snapshots (memory `project_composition_golden_survivor_bias.md`) is still present. The right control is the full PIT-rolling broader-universe scenario (still un-built per the `dev/notes/11knob-plateau-verdict-2026-05-24.md` discussion). For a fast experiment, top-3000-YYYY frozen-per-year is acceptable — the survivor bias is a separate confound, not the question we're settling here.
- **Sweep:** v4-style BO + v6-style random, budget 30 each (lighter than v4's 60 since the fold-count is different and we have a cleaner signal target).
- **Outcome to look for:** does BO/random on 1998-2009 produce a candidate that beats Cell E by enough to flip the fold-gate? If YES, today's "plateau" is overfit-to-2010-2026 specific. If NO, the strategy class itself has reached a ceiling.

**Effort:** ~80-150 LOC to wire the new fold spec + new BO spec. Plus ~12h sweep wall × 2 (BO + random). Material work but bounded.

### P0c — Component-decomposition objective

**Why third:** still worth doing regardless of P0a/b outcomes. Even on
the same SP500-2010-2026 surface, decomposing the objective into
per-component scores can reveal **which knobs are actually moving which
metric** — even if the global Composite stays flat.

**Per `dev/plans/tuning-methodology-redesign-2026-05-22.md` §2.8:**

```
score = w1·screener_quality + w2·portfolio_health + w3·order_fill + w4·stop_efficacy
```

Each component is a separately-measurable signal. BO targets the weak
one; we're no longer drowning a per-component improvement in the noise
of the global P&L.

**Effort:** ~200-400 LOC + 12-20h CPU per sweep. Larger than P0a/b.
Defer until P0a is landed (so the surface is navigable for the
decomposed objective too).

## Suggested sequencing

| Session | Work |
|---|---|
| N+1 | P0a (gate penalty) — single PR, all-in-day. Re-score v4/v6 checkpoints to validate. |
| N+2 | P0b — build the 1998-2009 fold spec + universe wiring; launch BO + random sweeps. |
| N+3 | P0b — harvest sweep results; act on findings. |
| N+4-5 | P0c — design + implement component-decomposition objective. |

Each item is gateable on the previous; if P0a flips the surface into
something the optimizer can navigate, both P0b's experiment design and
P0c's objective might shift accordingly.

## Other lower-priority work

- **Re-baseline the gate.** If P0b reveals Cell E isn't actually
  optimal on never-seen data, the gate's "beat Cell E in 17/30" criterion
  may itself be the wrong target. Could shift to "beat BAH SPY in 17/30"
  or "absolute Sharpe ≥ 0.5" — un-couples optimization from a comparator
  that may not be valid.
- **Tuning-methods steps 1-3 (TPE / Hyperband / CMA-ES)** stay DEMOTED
  per the v6 verdict. Revisit only if P0a's surface reveals exploitable
  structure that GP-EI is poorly suited for.
- **Snapshot cleanup hook** in `Panel_runner` (per safe-sweep infra plan
  §3) — moderate priority; would let future sweeps not require the
  manual hourly cron-clean dance.

## References

- `dev/notes/v6-random-baseline-verdict-2026-05-24.md` (this doc revises
  parts of it; see "v6-verdict claim" table above)
- `dev/notes/11knob-plateau-verdict-2026-05-24.md`
- `dev/notes/full-2019-pool-baseline-2026-05-23.md` (broader-universe
  hypothesis disproved earlier in this session sequence)
- `dev/plans/tuning-methodology-redesign-2026-05-22.md` §2.8 (P0c origin)
- `dev/plans/safe-sweep-infrastructure-2026-05-24.md`
- `dev/plans/tuning-methods-track-2026-05-24.md` (steps 1-3 of which are
  now demoted)
- `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.ml:46-48`
  (the gate penalty code being targeted by P0a)
- `memory/project_composition_golden_survivor_bias.md` (P0b caveat)
