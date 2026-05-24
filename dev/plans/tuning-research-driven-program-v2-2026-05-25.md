# Tuning research-driven program — v2 (2026-05-25)

Supersedes `dev/plans/tuning-research-driven-program-2026-05-25.md` (the
v1 in #1290). v2 absorbs 5 design refinements from the
2026-05-24/25 review conversation and adds explicit milestones + task
lists.

## Deltas from v1

| # | Delta | Reason |
|---|---|---|
| 1 | **Cost-model: keep `retail_default`** (5bps spread, $0 commission). Observe high-turnover behavior; aggressive calibration deferred. | Explicit preference recorded; bake into Phase 2 if needed. |
| 2 | **1998-2026 + top-3000 PROMOTED to primary experiment.** Was framed as "PR-4 stress test." Top-3000-YYYY snapshots are **delisted-enriched** (verified: LEH appears in 1998), so survivor bias is far smaller than I claimed; ~80% as good as true PIT. The 2010-2026 SP500-PIT becomes the comparison reference. | Confirmed via grep that delisted stocks ARE in the snapshots; the original "survivor-biased" framing was based on the pre-delisted-endpoint era. |
| 3 | **"True PIT Russell 3000 1998-2026" as Phase 2 stretch.** Marginal improvement over delisted-aware top-3000; keep on the table for after the program lands. | Per user: "I want to leave it on the table." |
| 4 | **Drop Cell E baseline for 1998-2026 sweep.** Pareto vector for that experiment = Sharpe, MaxDD, pass-vs-SPY, pass-vs-BRK (no Cell E). Cell E baseline doesn't exist for that period and isn't worth re-computing. | Simplifies the experiment; Cell E is ceremonial as a baseline anyway. |
| 5 | **PR-1 fidelity dimension = fold-COUNT (not fold-length).** Strategy needs 30-week MA (~10 months) initialization → 3-month folds can't even generate signals. Tiered fidelity is N-folds-of-12-months. **Add an Ambitious 36-month tier** as a final-stage horizon-robustness check on top survivors. | Per user: "6 folds × 3 months would be very noisy given our trade signal is 30w." |

## Why this program (recap)

Three converging diagnoses from the v6 verdict + research triage
(`/tmp/tuning-frontier-research-2026-05-25.md`):

1. **GP-EI = random at budget 30-34 is the signature of a flat surface, NOT a poor optimizer.** Switching surrogate (TuRBO/SAASBO/etc.) is a category error at d=11.

2. **Cell E was hand-tuned on the same data.** Meta-overfit: selection bias under unbounded informal trials. No BO sweep can escape the human-iterated local max on the data the iteration happened on.

3. **Score spread ≈ 0.8 across 60+ samples is noise-floor evidence.** Per-fold variance exceeds knob-to-knob variance. Need variance reduction OR redefined objective OR more independent data.

The literature (Hvarfner ICML 2024, Schneider/Bischl AutoML 2025 best paper, López de Prado Deflated Sharpe, Daulton qNEHVI) is explicit: **change the problem, not the optimizer.**

## Program structure — 4 PRs + 1 sweep + 1 stretch

```
PR-1 — Multi-fidelity + CRN fold pairing       ──┐
                                                  │
PR-2 — qNEHVI + multi-baseline constraint       ──┼── Infrastructure (3 sessions)
                                                  │
PR-3 — Deflated Sharpe + outer holdout         ──┘
                                                  │
PR-4 — 1998-2026 + top-3000 fold spec + Cell E ──┴── New fold spec (1 session)
       baseline drop + qNEHVI sweep launch
                                                  │
[Sweep run on the new fixture, harvest results]  ──── ~30-50h wall-time (unattended)
                                                  │
Phase 2 stretch — True PIT Russell 3000          ──── Deferred; reopen after sweep result
```

Total infra + experiment cycle: **5-7 sessions of focused work + 30-50h sweep wall**.

---

## Milestone M1 — PR-1: Multi-fidelity (fold-count) + Common Random Numbers

**Goal:** reduce per-eval cost via cheap-fidelity pruning + cut noise via paired-fold scoring. Surface becomes navigable; optimizer gets real gradient signal.

**Fidelity tiers (all uniform 12-month folds; fold-COUNT varies):**

| Tier | Folds | Time coverage | Cost (vs current) | Filters down to |
|---|---:|---|---:|---:|
| Cheap | 6-8 folds × 12m | ~12 years sampled | ~1/4 | top 50% of candidates |
| Medium | 12-15 folds × 12m | ~12 years | ~1/2 | top 25% |
| Expensive | 26 folds × 12m | 16 years | 1.0 | top 10-15% |
| **Ambitious** | **8-10 folds × 36m** | **~24 years overlap** | **~1.0** | **horizon-robustness test on final survivors** |

The Ambitious tier is the last-stage filter — only the candidates that survived the Cheap→Medium→Expensive pipeline get re-evaluated on long-horizon folds. Tests whether a candidate's edge survives ×3 longer time periods.

**Common Random Numbers (CRN):** the same fold-set is used across all candidates within a tier. Score = paired Δ-vs-Cell-E (per-fold delta), not absolute. Per-fold differences have far lower variance than per-fold absolutes.

### Tasks

- [ ] **T1.1 — Walk-forward fixture: heterogeneous-tier spec.** New `Window_spec.Tiered` variant. Each tier = fold count + horizon. ~80 LOC + tests.
- [ ] **T1.2 — Runner mode: fidelity-aware promotion.** `bayesian_runner.exe --fidelity-strategy successive_halving` flag. Cheap → Medium → Expensive promotion. Ambitious as a separate final stage. ~150 LOC.
- [ ] **T1.3 — Scoring: paired Δ-vs-Cell-E.** `Bayesian_runner_scoring.paired_delta` — for each candidate, compute per-fold Δ vs the corresponding Cell E baseline aggregate fold. Aggregate is mean of Δ's, not mean of absolutes. ~50 LOC.
- [ ] **T1.4 — Calibration: proxy-fidelity correlation.** Pre-flight: run Cell E on the 6-fold cheap proxy and the 26-fold expensive set; compute Spearman ρ. Require **ρ ≥ 0.7** for the proxy to be acceptable. ~30 LOC + run.
- [ ] **T1.5 — Re-score v4/v6 checkpoints.** Apply the new paired-Δ scoring to existing on-disk checkpoints; verify surface has visible structure (spread > 5× the old 0.81). Pure data analysis, no re-simulation. ~30 LOC.

### Acceptance

- All tests pass.
- T1.4 calibration result documented: `ρ ≥ 0.7` between cheap and expensive on Cell E's neighborhood.
- T1.5 re-score: v4+v6 data on paired-Δ shows >5× wider spread than the original flat -10 plateau.

### Effort

~400-600 LOC + ~200 LOC tests. 1 session.

---

## Milestone M2 — PR-2: qNEHVI multi-objective with multi-baseline constraint

**Goal:** replace the scalar Composite blend with a Pareto frontier. Treat passive-baseline beating as a constraint (must-have) and Sharpe / DD / active-baseline as soft objectives.

### Pareto vector (4 dimensions, low-correlation)

```
maximize Pareto-front of:
  • mean_sharpe                   (higher is better)
  • mean_max_drawdown_pct         (lower is better — flipped sign)
  • pass-rate-vs-BAH-BRK          (higher is better — soft, "ambitious bar")
subject to constraint:
  • pass-rate-vs-BAH-SPY ≥ 17/30  (hard, "must beat passive")
```

When the 2010-2026 setup runs (alongside the primary 1998-2026 setup), it adds Cell E pass-rate:

```
maximize Pareto-front of:
  • mean_sharpe
  • mean_max_drawdown_pct
  • pass-rate-vs-BAH-BRK
  • pass-rate-vs-Cell-E           (retained for continuity with prior measurements)
subject to:
  • pass-rate-vs-BAH-SPY ≥ 17/30
```

### Rationale for constraint vs objective on SPY

User insight: failing to beat SPY is qualitatively worse than failing to beat BRK. "A strategy that closely tracks BRK while beating SPY is still useful" — capture this by making SPY a binary constraint (must-pass) and BRK a continuous objective (more pass-rate = better).

### Tasks

- [ ] **T2.1 — Baseline aggregates.** Compute BAH SPY + BAH BRK-A aggregates for each fold in the canonical 2010-2026 spec. These are cheap (pure price arithmetic, no strategy simulation). ~50 LOC + 1 batch run.
- [ ] **T2.2 — Multi-objective scoring module.** `Bayesian_runner_scoring.multi_objective` returning a vector of objectives + a vector of constraints. ~150 LOC + tests.
- [ ] **T2.3 — qNEHVI acquisition.** Either BoTorch FFI (Python sidecar) OR homegrown port. Decision: homegrown — qNEHVI's core is a hypervolume + Monte Carlo improvement calculation, ~200-300 LOC in OCaml without exotic dependencies. ~300 LOC + tests.
- [ ] **T2.4 — Constraint handling.** Outcome-constraint mask on the acquisition function: candidates failing the SPY constraint get infinite penalty / zero acquisition value. ~80 LOC.
- [ ] **T2.5 — Runner integration.** `bayesian_runner.exe --objective multi --constraint pass_vs_spy>=17/30`. ~50 LOC plumbing.
- [ ] **T2.6 — Sanity sweep.** Small-budget (20-iter) run on the 2010-2026 spec. Manual inspection of the Pareto front. ~5h wall.

### Acceptance

- Hypervolume + dominance unit tests pass against fixture values.
- T2.6 sanity sweep produces a Pareto front of ≥ 3 distinct configurations.
- At least one candidate dominates Cell E on a 2-axis subset (Sharpe + Calmar OR Sharpe + DD) — OR the run shows no dominator across 20 iters (also a finding).

### Effort

~600-900 LOC + ~300 LOC tests + 1 sanity-sweep run. 2 sessions.

---

## Milestone M3 — PR-3: Deflated Sharpe Ratio + outer holdout enforcement

**Goal:** address meta-overfit at two layers: trial-bias deflation on the winner's reported metric, and a separate holdout fold the optimizer never sees.

### Tasks

- [ ] **T3.1 — DSR formula port.** Bailey & López de Prado closed-form. Pure-OCaml implementation; no exotic dependency. Inputs: candidate Sharpe + Sharpe distribution across folds + trial count N. Output: deflated Sharpe. ~50 LOC + tests against fixture values from the paper.
- [ ] **T3.2 — Outer-holdout fold spec.** `Walk_forward.Spec.outer_holdout_folds` field — separate from `holdout_folds` (which already exists for BO-internal OOS validation). The optimizer NEVER sees these folds during the sweep; consulted only for final go/no-go decision. ~30 LOC.
- [ ] **T3.3 — Promotion gate.** After a sweep completes, the "winner" (Pareto front member to be promoted) must pass: (a) DSR-deflated Sharpe ≥ Cell E DSR-deflated Sharpe (b) outer-holdout pass-rate ≥ threshold. ~50 LOC + integration test.
- [ ] **T3.4 — Re-score historical sweeps.** Apply DSR deflation to v4/v6 winners. Confirm the v4 BO "best" of -9.6516 is correctly rejected when DSR is applied (likely outcome, given the spread is dominated by gate-penalty noise). ~20 LOC.

### Acceptance

- T3.1 reproduces paper Table 1 DSR values for fixtured (Sharpe, N, fold_count) inputs.
- T3.4 confirms v4/v6 winners do not survive DSR deflation (or they DO, which is a meaningful finding).

### Effort

~200 LOC + ~150 LOC tests. 1 session.

---

## Milestone M4 — PR-4: 1998-2026 + top-3000 fixture + primary sweep

**Goal:** run the canonical experiment of the program. Verify that the 11-knob surface, evaluated on a 28-year delisted-aware top-3000 universe, produces results that meaningfully differ from the 2010-2026 SP500 picture.

### Why this is primary, not stress-test (v2 promotion)

Top-3000-YYYY snapshots are delisted-enriched (verified: LEH in 1998 snapshot). Survivor bias is far smaller than initially characterized. With the delisted endpoint enrichment, the remaining gap to "true PIT Russell 3000" is marginal. **This setup IS substantially PIT-correct over 28 years × 3000 symbols.**

### Tasks

- [ ] **T4.1 — Walk-forward fixture for 1998-2026.** New `cell_e_full_history_28fold_2026_05_25.sexp` — start 1998-01-01, end 2026-04-30, test_days 365, step_days 365 (annual non-overlapping = ~28 folds) OR step_days 182 (~56 folds for finer granularity). Universe pointer: `top-3000-YYYY.sexp` rotating per fold start year. ~50 LOC + fixture.
- [ ] **T4.2 — Per-fold universe rotation in `Panel_runner`.** Confirm the screener / panel-runner already supports "different universe per fold" (per #1089 + #1094 `membership_at` callback). If not, ~80 LOC to plumb.
- [ ] **T4.3 — BAH SPY + BAH BRK-A aggregates for 1998-2026.** Same 28-fold spec, compute passive baselines. Cheap: pure price arithmetic. ~30 LOC + 1 batch run.
- [ ] **T4.4 — Sanity backtest of Cell E on the new fixture.** Confirm strategy runs end-to-end + produces non-NaN metrics across all 28 folds. ~5h wall.
- [ ] **T4.5 — Launch primary sweep.** BO with qNEHVI from M2 + DSR / outer-holdout from M3 + multi-fidelity from M1 against the new fixture. **Budget 60.** Output to `/tmp/sweeps/11knob-v7-full-history-qnehvi/`. **~30-50h wall-time** (unattended).
- [ ] **T4.6 — Harvest + writeup.** When sweep completes, extract Pareto front, run DSR + outer-holdout gates, write verdict doc.

### Pareto vector for this experiment (Cell E dropped)

```
maximize:
  • mean_sharpe
  • mean_max_drawdown_pct (flipped)
  • pass-rate-vs-BAH-BRK-A
subject to:
  • pass-rate-vs-BAH-SPY ≥ threshold
```

### Acceptance

- T4.1 fixture parses + sanity-loads.
- T4.4 confirms strategy runs cleanly on the new universe + period.
- T4.5 sweep completes 60 iters without crash.
- T4.6 verdict doc identifies: either (a) candidate(s) on the Pareto front that dominate Cell E + survive DSR + outer-holdout — meaningful improvement, OR (b) no such candidate — the strategy class has reached its ceiling.

### Effort

~200 LOC + ~30-50h sweep wall. 1-2 sessions of code + 1 session to harvest.

---

## Phase 2 stretch — True PIT Russell 3000 universe

**Not in this program's critical path. Listed for visibility.**

Per memory `project_eodhd_delisted_unlock.md` and the data-foundations track:

- Acquire historical Russell 3000 membership rolls (paid scraper API ~$20-50 one-shot, OR EODHD Fundamentals tier $59.99/mo, OR Sharadar via Nasdaq Data Link $99/mo)
- Wire historical membership through the universe layer
- Rerun the M4 sweep against the true-PIT-Russell-3000 fixture

**When to revisit:** if M4's results are ambiguous (Pareto front exists but the survivor-bias-residual is non-trivial), or if a candidate's improvement is small enough that the residual bias could explain it.

**Effort estimate:** ~$20-200 spend + ~200-400 LOC data engineering. 1-2 sessions.

---

## Total program estimate

| | LOC | Sweep wall | Sessions |
|---|---:|---:|---:|
| M1 (PR-1) Multi-fidelity + CRN | ~700 | calibration only | 1 |
| M2 (PR-2) qNEHVI + multi-baseline | ~1100 | ~5h sanity | 2 |
| M3 (PR-3) DSR + outer holdout | ~350 | none | 1 |
| M4 (PR-4) 1998-2026 primary sweep | ~200 | ~30-50h | 1-2 + 1 harvest |
| **Total infra** | **~2350** | **~35-55h** | **5-7** |
| Phase 2 stretch (true PIT) | ~300 + $20-200 | rerun M4 | 1-2 |

---

## What this program does NOT do

- **No different optimizer family.** Per the research, surrogate change isn't the lever at d=11.
- **No aggressive cost-model preset.** Stay at `retail_default`; observe; revisit only if a high-turnover winner survives the M4 verdict.
- **No "Cell E on 1998-2026" recompute.** Cell E baseline dropped for that experiment.
- **No more random-search baseline runs.** v6 settled that question; random ≈ BO at budget 60.
- **No 3-month or 6-month fold horizons.** Strategy needs 30-week MA init; sub-12-month folds can't generate signals.

## References

- `dev/plans/tuning-research-driven-program-2026-05-25.md` (v1 — superseded by this doc)
- `dev/notes/v6-random-baseline-verdict-2026-05-24.md` (v6 plateau verdict)
- `dev/notes/next-session-priorities-2026-05-25.md` (P0a/b/c — superseded)
- `/tmp/tuning-frontier-research-2026-05-25.md` (research triage — 11 papers cited)
- Hvarfner et al. ICML 2024 — vanilla BO performs great in high dimensions
- Daulton et al. NeurIPS 2021 — qNEHVI multi-objective BO
- Bailey & López de Prado 2014 — Deflated Sharpe Ratio
- Schneider, Bischl, Feurer AutoML 2025 (best paper) — overtuning in HPO
- Falkner, Klein, Hutter ICML 2018 — BOHB
- Santner & Wilson Mgmt Sci 1999 — Common Random Numbers foundational result
- `memory/project_eodhd_delisted_unlock.md` (delisted-endpoint discovery)
- `memory/project_composition_golden_survivor_bias.md` (the original survivor-bias diagnosis)
