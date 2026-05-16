# Bayesian multi-parameter optimisation — pre-registered hypothesis

## Date

2026-05-17

## Authority

`dev/plans/bayesian-multi-param-scaling-2026-05-16.md` §6 (validation
acceptance criterion). Predecessor PRs that produced this run's
ingredients:

- PR #1126 (PR-A) — scoring function + walk-forward aggregate consumer
- PR #1132 (PR-B) — knob inventory + 11-knob parameter space
- PR #1136 (PR-C) — walk-forward in-process integration
- PR #1143 (PR-D) — length-scale + early-stop + Option encoding
- PR-E (this PR) — end-to-end runner + OOS holdout validator

## Hypothesis

> The Phase-3 Bayesian optimiser on the 11-knob curated surface (PR-B
> bounds) converges to a cell whose mean walk-forward Sharpe on the
> 26 in-sample folds (1..26) of `cell_e_30fold_2026_05_16.sexp`
> exceeds Cell E's by ≥0.05 with MaxDD no worse by more than 1pp,
> AND whose out-of-sample mean Sharpe on the 4 held-out folds
> (27..30) is within 0.10 of the in-sample mean Sharpe.

The hypothesis is **pre-registered** before any production sweep. The
production sweep itself is an ops-session deliverable per plan §10 —
this experiment file pins the acceptance criteria so the verdict
cannot be retrofitted to a post-hoc result.

## Setup

| Lever | Value |
|---|---|
| BO spec | `trading/test_data/tuner/bayesian-multi-param-2026-05-16.sexp` |
| Walk-forward spec | `trading/test_data/walk_forward/cell_e_30fold_2026_05_16.sexp` |
| Universe | sp500-2010-2026 (`goldens-sp500-historical/sp500-2010-2026.sexp`) |
| Knob count | 11 (Tracks A/B/D/E per plan §2.1) |
| Initial random samples | 25 |
| Total budget | 100 BO iterations (~25 wall-clock hours) |
| Acquisition | Expected_improvement |
| GP length-scales | default (~`sqrt(d) * 0.25`) |
| Early-stop | disabled in v1 (plan §5.4) |
| Seed | 2026 |
| Baseline | Cell E (no-op overrides on `cell_e_30fold_2026_05_16` baseline) |
| Holdout folds | (27 28 29 30) — last ~13% of the 30-fold spec |
| Score formula | `mean_sharpe(cell) - λ_dd * max(0, excess_maxdd) - λ_gate * gate_penalty` (plan §3.1; PR-A) |

## Acceptance criteria (per plan §6)

### In-sample (§6.1)

The best cell's mean walk-forward Sharpe (over folds 1..26) must:

1. **Beat Cell E by ≥0.05 Sharpe.**
   - Cell E baseline mean Sharpe on folds 1..26: TBD (read from the
     baseline aggregate produced by running Cell E through the full
     spec).
2. **MaxDD no worse than Cell E by more than 1pp.**
3. **Pass the M-of-N gate** (Sharpe, M=17, N=30, worst_delta=0.30 —
   per the walk-forward spec).

### Out-of-sample (§6.2 + §6.3 — no-overfit hurdle)

After in-sample acceptance, re-run the best cell on the held-out folds
(27..30) and confirm:

4. **OOS mean Sharpe is within 0.10 of in-sample mean Sharpe**
   (`abs(oos_mean_sharpe - in_sample_mean_sharpe) <= 0.10`).

A gap > 0.10 signals the BO over-fit the in-sample folds; the cell is
rejected for production pinning regardless of how strong the in-sample
result is. This guardrail is the discipline shift from prior M5.5
sweeps that landed winners on a single window without an OOS check —
several of which (axis-1 ×2 cross sweep 2026-05-14, continuation-
combined 2026-05-14) failed 16y validation despite winning the short
window. The PR-E OOS validator emits `oos_report.md` automating this
check.

## Falsification criteria

The hypothesis is **not supported** if any of:

1. The BO budget exhausts (100 iterations) without producing a cell
   that meets in-sample criterion (1) — the best cell improves Sharpe
   by <0.05, OR improves Sharpe but worsens MaxDD by >1pp, OR fails
   the M-of-N gate.
2. The best cell meets in-sample criteria 1-3 but fails the no-overfit
   hurdle (criterion 4): `|OOS - in-sample| > 0.10`.
3. The BO converges to a degenerate cell — one whose mean Sharpe is
   driven by the gate penalty hinge (e.g. `-9.x` score from a Fail
   verdict). The `oos_report.md` shows `Reject_insufficient_data`
   verdict when no OOS folds match (operational failure mode, not a
   strategy failure).

Any of these falsifications is itself a useful finding: the 11-knob
curated surface (which deliberately omits Tracks C and the
Option-typed knobs) does not contain a cell that beats Cell E on both
in-sample and held-out folds. The follow-up is plan §10's "Path A
(extend the in-house GP) + Path B (random-search-only mode)"
fork-choice question, with the random-search baseline run as a
sanity-check on whether the surface itself is the limiting factor.

## What this experiment does NOT prove

- It does not prove Cell E is optimal on the surface; the curated
  11-knob surface excludes Track C (stage classifier) entirely. A
  cell beating Cell E on Tracks A/B/D/E is consistent with another
  cell, on the full 18+ knob surface, beating it by more.
- It does not prove the strategy generalises beyond 2010-2026. The
  Russell-3000 pre-2010 universe is a Phase-1 follow-up (per plan §10
  "Out of scope"); when that lands, this experiment should be re-run
  on the wider window before re-pinning Cell F.
- It does not prove the `λ_dd = 0.10` hyperparameter is correct.
  λ_dd is the operator-policy MaxDD-vs-Sharpe trade-off; a different
  value produces a different optimum even on the same surface. Plan
  §3.1 fixes λ_dd at 0.10 for v1; a follow-up may sweep.

## Run plan

The actual sweep is an ops-session deliverable per plan §10. This
hypothesis file is committed alongside PR-E. The sweep run produces
`out_dir/oos_report.md` whose verdict block plus the in-sample/OOS
gap is the experiment's report.

## How the verdict is logged

Once the BO has run and PR-E emitted `oos_report.md`:

- If `Accept`: pin the best cell as Cell F in a follow-up PR, then
  re-run the 15y golden against it for the long-window check.
- If `Reject_overfit`: file an issue noting which knobs the BO moved
  and which holdout fold(s) drove the gap; consider whether the BO
  surface needs further curation OR whether random-search is the
  better path.
- If `Reject_insufficient_data`: operational failure (no holdout folds
  matched); fix the spec's `holdout_folds` and re-run.

## Reproducibility

- BO seed pinned to 2026 in `bayesian-multi-param-2026-05-16.sexp`.
- Walk-forward spec pinned via `cell_e_30fold_2026_05_16.sexp`.
- Universe pinned via the baseline scenario sexp (which itself pins
  the 2026-05-13 510-symbol roster).
- All PR-A through PR-E commits land on `main` before the sweep.

Re-running the sweep with the same inputs is byte-deterministic per
the BO library's determinism contract (`bayesian_opt.mli` §"Pinned by
test_determinism_same_seed_same_sequence"). The OOS validator is
pure (no I/O during scoring); same fold_actuals → same verdict.
