# Tuning research-driven program (2026-05-25)

> **SUPERSEDED by `dev/plans/tuning-research-driven-program-v2-2026-05-25.md`.**
> v2 absorbs 5 design refinements from the post-publication review
> conversation (cost-model preference, 1998-2026 promoted to primary
> via delisted-aware top-3000, Cell E baseline dropped for that
> experiment, fold-COUNT fidelity instead of fold-length, true PIT as
> Phase 2 stretch) and adds explicit milestones + task lists.
> This v1 is retained for the reasoning path.

Concrete plan for the next-session tuning work, derived from the
2026-05-25 frontier-research triage at
`/tmp/tuning-frontier-research-2026-05-25.md` (cited papers below).
Supersedes the P0a/b/c list in
`dev/notes/next-session-priorities-2026-05-25.md` — those items were
correct in direction but the research suggests a much cleaner
formulation. Old P0s referenced from the research perspective:

| Old P0 | Status | Replacement |
|---|---|---|
| P0a soft gate penalty | Subsumed | Multi-fidelity + Common Random Numbers (Rec #1) — better attack on the noise floor than coefficient tuning |
| P0b Cell-E-never-saw experiment | Generalized | Outer-holdout discipline (Rec #2, M12) — do unconditionally, not as a separate sweep |
| P0c Component decomposition | Subsumed | qNEHVI multi-objective BO (Rec #2, M8) — Pareto frontier IS the principled component decomposition |

The research's two top recommendations are themselves complementary —
together they address the three converging diagnoses of why current
tuning is plateaued.

## Why this program (the three converging diagnoses)

From the research report:

1. **GP-EI = random at budget 30-34 is the signature of a near-flat surface, NOT a poor acquisition function.** Confirmed empirically (v4 vs v6). Switching to TuRBO / SAASBO / CMA-ES is a category error at d=11; the bind is elsewhere.

2. **Cell E was hand-tuned on the same data the BO compares against.** This is meta-overfit: selection bias under unbounded informal trials (López de Prado, Bailey & López de Prado 2014). Any 50-200 trial-budget BO sweep cannot escape the upper bound the human grid-searched against by attention.

3. **Score spread ≈ 0.8 across 60+ samples is noise-floor evidence.** Per-fold variance exceeds knob-to-knob variance at the aggregate level. No acquisition function recovers signal that's below the noise floor; need either more independent data, variance reduction, or a redefined objective.

The research literature (Hvarfner ICML 2024, Schneider/Bischl AutoML 2025, López de Prado, Daulton qNEHVI) is explicit:

> The literature does not say "use method X for flat surfaces near a hand-tuned reference." It says: **change the problem.**

Specifically: (a) more independent data, (b) variance reduction, (c) redefined objective, (d) outer holdout calibration. The "switch optimizer" lever is 1-2×; (a)-(d) are 5-10× and fix the failure mode that 1-2× cannot.

## Three PRs (sequence as listed; each gated on prior landing)

### PR-1 — Multi-fidelity (fold-subset) + Common Random Numbers fold pairing

**What it does:**
- Treat the 26-fold panel as a controllable fidelity dimension. Define a "cheap" fidelity = 4 or 6 representative folds; measure correlation with the 26-fold objective on `C*`'s neighborhood. Use BOHB/DEHB-style pruning: full-fold evaluation only for survivors.
- Common Random Numbers (CRN): pair the same fold-set across candidates. Score paired Δ-vs-`C*` instead of absolute scores. Per-fold *differences* have much lower variance than per-fold *absolutes*.

**Why it works:** 5-10× effective budget multiplier (multi-fidelity) + direct noise-floor attack (CRN pairing). This is the highest-leverage available change.

**Scope:**
- New runner mode in `bayesian_runner.exe`: `--fidelity-subsets <4|6|26>` with promotion rules.
- New scoring path: `paired_delta_vs_baseline` instead of raw aggregate.
- Pre-flight calibration: pick the proxy fold-set; measure Spearman ρ vs the 26-fold objective on `C*`'s neighborhood; require ρ ≥ 0.7 for the proxy to be usable.

**Acceptance:**
- Unit tests: fold-subset selection, CRN pairing logic.
- Calibration result: ρ ≥ 0.7 documented in a results note.
- v6-data re-score on the paired-Δ objective: spread > 5× the old 0.81 (visible structure instead of flat plateau).

**Estimated effort:** ~400-600 LOC + ~200 LOC tests + 1 calibration run.

### PR-2 — Multi-objective BO with qNEHVI + multi-baseline vector

**What it does:**

Replace the scalar Composite objective with a Pareto-frontier objective.

**Objective vector — 4 dimensions (low-correlation, computationally tractable):**

| Objective | Direction | Why keep |
|---|---|---|
| `mean_sharpe` | maximize | Primary return-risk metric |
| `mean_max_drawdown_pct` | minimize (flipped sign) | Tail/risk-side; not captured by Sharpe |
| `pass-rate-vs-Cell-E` | maximize | "Beat our hand-tuned reference" |
| `pass-rate-vs-BAH-SPY` | maximize | "Beat passive market beta" |

**Why 4 and not more.** Multi-objective BO loses discriminating power as the vector dimension grows: the Pareto frontier inflates, hypervolume compute scales `O(N^(d_obj-1))`, and correlated axes waste capacity. Conservative sweet spot per literature is 3-5 objectives. Dropping rationale:

- `mean_calmar` — derived from Sharpe + MaxDD; compute downstream if needed.
- `pass-rate-vs-BAH-BRK` — partially correlated with SPY for the 2010-2026 period; only worth adding if a specific BRK-hypothesis emerges. Add as a 5th dim if motivated.
- `pass-rate-vs-S&P-5 / -10` — highly correlated with SPY at the mega-cap concentration level; drops capacity without independent signal.

**Add a 5th objective ONLY if the Pareto front isn't producing meaningful winners at 4 dims.** First-instance starts simple.

Use BoTorch's `qLogNEHVI` (or homegrown port if dependency cost too high). The acquisition function picks candidates that improve the Pareto hypervolume.

**Why it works:** sidesteps the hand-tuned scalar blend entirely. No more "0.40 Sharpe + 0.30 Calmar - 0.10 MaxDD" arbitrary weights. No more single-baseline meta-overfit (Cell E specifically). The output is a Pareto set; the human picks the trade-off post-hoc.

**On the multi-baseline question:**

The current setup has Cell E as the single comparator. Per the user's critique, this bakes in Cell E's specific properties. Switching to a *single* alternative (e.g. BRK) trades one bias for another. The research-endorsed answer is **multi-objective dominance over multiple baselines**: a candidate must dominate on the Pareto front including pass-rates against all of {Cell-E, SPY, BRK, S&P-5, ...} — a much stronger criterion than beating any single one.

| Baseline | What it tests for | Bias it would introduce alone |
|---|---|---|
| Cell E | Meta-overfit to hand-tuned local max | Selection bias on same data |
| BAH SPY | Beating market beta | Index/beta tracking bias |
| BAH BRK | Smart-money active reference | Time-period-specific Apple-position dynamics |
| S&P 5 / S&P 10 | Mega-cap concentration | FAANG/MAG7 momentum bias |
| Equal-weight | Naive diversification | None obvious; mostly a noise floor |

All five together → multi-objective Pareto vector. Optimizer rewarded for dominating broadly, not narrowly.

**Scope:**
- New objective module: `Bayesian_runner_scoring.multi_objective` returning a vector.
- New acquisition: qLogNEHVI implementation OR BoTorch FFI / Python sidecar (decision pending).
- Per-fold baseline running: each fold backtests the new candidate AND all baselines under CRN.

**Acceptance:**
- Unit tests: hypervolume computation, dominance check.
- Pareto frontier produced from a small-budget run (~20 evals); manual inspection.
- v4/v6 data re-scored on the multi-objective view: at least one prior sample dominates Cell E on a strict subset of (Sharpe, Calmar) axes (if not — the meta-overfit verdict was correct AND the strategy class has no slack).

**Estimated effort:** ~600-900 LOC + ~300 LOC tests + 1 small validation sweep.

### PR-3 — Deflated Sharpe + Outer holdout enforcement

**What it does:**
- Implement Deflated Sharpe Ratio (DSR) scoring (Bailey & López de Prado 2014): closed-form correction for the selection-bias inflation in "best of N trials." A candidate's raw Sharpe is deflated by the expected best-of-N boost under the null.
- Enforce outer holdout: at least 1 fold (probably 2-3) reserved as never-seen-by-the-optimizer. Final go/no-go decision based on the candidate's OOS holdout performance, not in-sample BO score.

**Why it works:** per Schneider/Bischl AutoML 2025 best paper — aggressive HPO with noisy validation makes generalization *worse* in ~10% of cases. The outer holdout is the canonical defense; DSR is the closed-form penalty for trial-bias.

**On the user's "Cell-E-never-saw" question:**

This PR generalizes the proposal in `dev/notes/next-session-priorities-2026-05-25.md` (P0b). Instead of running a separate Cell-E-never-saw experiment as a one-shot, the outer-holdout discipline becomes a *permanent feature* of the tuning pipeline. Every BO run reserves an unseen slice; the optimizer never sees it; final promotion requires the holdout pass.

The Schneider/Bischl framing also justifies running a separate **time-period out-of-sample experiment** (e.g. 1998-2009 fold spec on top-3000-YYYY universes) IF the in-sample run produces a "winner." The holdout discipline ensures the in-sample winner is calibrated before being trusted on truly out-of-sample data.

**Scope:**
- DSR formula port (pure OCaml from the Bailey/López de Prado closed form).
- Walk-forward fixture: explicit `outer_holdout_folds` field (separate from `holdout_folds` which is already used for OOS validation post-BO; this would be even-further-removed).
- Promotion gate: require outer-holdout Sharpe ≥ Cell-E + (DSR penalty) before any "winner" claim.

**Acceptance:**
- DSR computation matches the closed-form formula for fixtured inputs (paper Table 1 values).
- A v4-data BO winner that DOESN'T survive DSR + outer-holdout is correctly rejected.
- Test confirms a known-good (synthetic) winner passes both.

**Estimated effort:** ~200 LOC + ~150 LOC tests.

## Complete option-comparison table

Every alternative tuning methodology considered across today's session,
plus the research findings. Status reflects 2026-05-25 PM state.

| Option | What it does | Status | Reason |
|---|---|---|---|
| **GP-EI BO (current)** | Standard Bayesian optimization with Expected Improvement | **CONFIRMED PLATEAUED** | v4 sweep 34 iters; no acquisition iter beat best random |
| **Uniform random search** | Pure random sampling, no surrogate | **CONFIRMED MATCHES BO** | v6 sweep 29 iters; same best score as v4 BO |
| TPE | Tree-structured Parzen Estimator | **DEMOTED** | Per v6 verdict — surface is the bind, not the surrogate |
| Hyperband alone | Successive halving + early-stop pruning | **REVIVED AS PR-1** | Becomes multi-fidelity component of the research-endorsed program |
| CMA-ES | Evolution strategy | **DEMOTED** | Needs O(d²) ≈ 100+ evals; not competitive at our budget |
| Learned surrogate (XGBoost on past samples) | Train ML model on (knobs → score) pairs | **DEMOTED** | 63 samples too few for any reasonable d=11 learned surrogate |
| Vanilla BO + dim-scaled prior (Hvarfner 2024) | √d-scaled GP lengthscale prior | **OPTIONAL** | Mandatory baseline; near-zero cost; won't qualitatively change the result |
| TuRBO | Local trust-region BO | **DEMOTED (diagnostic only)** | At d=11 with hand-tuned local max, will confirm plateau rather than escape |
| SAASBO | Sparse axis-aligned subspace BO | **NOT APPLICABLE** | Designed for d ≥ 20; HMC overhead not worth it at d=11 |
| BAxUS / nested random embeddings | High-D BO via subspace embedding | **NOT APPLICABLE** | Designed for d ≫ 50 |
| Probabilistic Reparameterization (PR) | Continuous AF over mixed/integer spaces | **OPTIONAL** | LOW-MED cost; addresses our 4 int knobs; worth doing as a tweak |
| **Multi-fidelity (BOHB/DEHB) + fold-subset fidelity** | Cheap-fidelity pruning via fold subsets | **PR-1 OF PROGRAM** | 5-10× budget multiplier; highest-leverage change available |
| **Common Random Numbers (fold pairing)** | Paired-fold Δ scoring reduces noise | **PR-1 OF PROGRAM** | Direct attack on the noise floor; ~50 LOC plumbing |
| Level-set BO | "Find region where f ≥ τ" instead of "find max" | **STRETCH** | Research-grade; encode-as-constraint in qNEHVI instead |
| **Multi-objective BO (qNEHVI)** | Pareto frontier over multiple metrics | **PR-2 OF PROGRAM** | Replaces hand-tuned scalar blend; subsumes component-decomposition; addresses user's "learned scoring" instinct |
| **Multi-baseline objective extension** | Pareto vector includes pass-rates vs {Cell-E, SPY, BRK, S&P-5} | **PR-2 EXTENSION** | Per user's 2026-05-25 critique; dilutes single-baseline bias |
| Soft gate penalty (coefficient calibration) | Continuous penalty instead of binary -10 | **SUBSUMED** | Subsumed by Multi-fidelity + CRN (PR-1) which attacks the same noise-floor problem at higher leverage |
| Component decomposition (`w1·screener + w2·portfolio + ...`) | Per-component scoring instead of global P&L | **SUBSUMED** | Subsumed by qNEHVI multi-objective (PR-2) — Pareto IS the principled per-component view |
| Cell-E-never-saw out-of-sample experiment | Separate sweep on 1998-2009 + broader universe | **GENERALIZED** | Generalized to outer-holdout discipline (PR-3); also valuable as a follow-up experiment |
| **Deflated Sharpe Ratio + Outer holdout** | Selection-bias-corrected scoring + un-tuned validation fold | **PR-3 OF PROGRAM** | Schneider/Bischl AutoML 2025 + López de Prado; addresses meta-overfit unconditionally |
| Learned aggregator (small NN replacing composite weights) | NN predicts score from per-fold metrics | **SUBSUMED** | Same idea as qNEHVI multi-objective at a higher abstraction; Pareto is the canonical formulation. Could re-visit as a stretch if qNEHVI doesn't reveal structure. |
| Switch single baseline (Cell-E → BRK / SPY / S&P-5) | Replace comparator with non-Cell-E reference | **NOT DONE — biased** | Single-baseline swap trades one bias for another. Multi-baseline (PR-2 extension) is the principled answer. |

## Effort summary

| | LOC | Wall (sweeps) | Sessions |
|---|---|---|---|
| PR-1 (multi-fidelity + CRN) | ~600-800 | ~15h sweep | 2-3 |
| PR-2 (qNEHVI + multi-baseline) | ~900-1200 | ~12h sweep | 2-3 |
| PR-3 (DSR + outer holdout) | ~350 | calibration only | 1 |
| **Total** | **~1800-2400** | **~30h sweep wall** | **5-7** |

## Sequencing

Each PR is gated on the prior:

- PR-1 (multi-fidelity + CRN) lands first. Validates that the noise floor can be reduced; if NOT, the whole program's premise weakens.
- PR-2 (qNEHVI) builds on PR-1's noise-reduced data. The Pareto frontier needs paired Δ scoring to be meaningful.
- PR-3 (DSR + outer holdout) can land alongside PR-2 OR after — it's a scoring overlay, doesn't depend on the underlying optimizer.

## What this program does NOT do

- Doesn't try a different optimizer family. Per Hvarfner / NeurIPS 2024 benchmark / the v6 verdict, surrogate-change isn't the lever.
- Doesn't run more iterations with the existing setup. v4 + v6 already gave us 63 evaluations of evidence that the surface is flat at this budget; doubling the budget produces more of the same.
- Doesn't bet on broader universe / longer history. Full-pool 2019 baseline (2026-05-23) showed broader universe degrades Sharpe; longer history needs better PIT universe data which is a separate track.

## References

- `/tmp/tuning-frontier-research-2026-05-25.md` — the underlying research triage
- `dev/notes/v6-random-baseline-verdict-2026-05-24.md` — the empirical evidence the program responds to
- `dev/notes/next-session-priorities-2026-05-25.md` — superseded P0a/b/c (kept for history)
- `dev/notes/11knob-plateau-verdict-2026-05-24.md` — earlier verdict
- Hvarfner et al. ICML 2024 — Vanilla BO Performs Great in High Dimensions
- Daulton et al. NeurIPS 2021 — qNEHVI multi-objective BO
- Bailey & López de Prado 2014 — Deflated Sharpe Ratio
- Schneider, Bischl, Feurer AutoML 2025 (best paper) — Overtuning in HPO
- Falkner, Klein, Hutter ICML 2018 — BOHB
- Awad, Mallik, Hutter IJCAI 2021 — DEHB
- Santner & Wilson Mgmt Sci 1999 — Common Random Numbers foundational result
