# Next-session priorities (2026-05-25)

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

**Change:**

```ocaml
(* In bayesian_runner_scoring.ml. Current: hardcoded 10.0 on Fail. *)
let _compute_gate_penalty ~value (verdict : Walk_forward.Fold_gate.verdict) =
  match verdict with
  | Pass _ -> 0.0
  | Fail { actual_m; required_m; worst_delta_actual; worst_delta_threshold; _ }
    ->
      (* Continuous in the gap: penalty grows linearly as candidate fails harder. *)
      let m_gap = Float.of_int (required_m - actual_m) in     (* ≥1 since Fail *)
      let delta_gap =
        Float.max 0.0 (worst_delta_actual -. worst_delta_threshold)
      in
      (* Tune the coefficients so a "barely failing" candidate gets ~1-2 penalty,
         not 10. A genuinely abysmal one still gets ~10. *)
      0.3 *. m_gap +. 5.0 *. delta_gap
```

Exact coefficients TBD by calibration on the v4/v6 data we have on disk
(`.sweep-output/11knob-v6-random/bo_checkpoint.sexp`). Goal: candidates
that fail by 1-2 folds get penalty ~0.3-0.6; candidates that fail
catastrophically still hit the original 10-equivalent magnitude.

**Test plan:**

- Unit test: gate-verdict fixtures with various `actual_m` / `required_m` /
  `worst_delta_actual` combos; assert continuous penalty mapping.
- Re-score the existing v4/v6 BO checkpoints with the new penalty (pure
  function of stored data, no re-run needed). Verify the surface now has
  visible structure rather than a flat -10 plateau.

**Effort:** ~50 LOC impl + ~80 LOC tests. 1 small PR.

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
