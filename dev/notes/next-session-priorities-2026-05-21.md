# Next-session priorities (for 2026-05-21)

Written end of session 2026-05-20.

## Substantive work shipped today (2026-05-20)

### M1 + M2 cross-cycle Weinstein validation

- **PR #1207** (M1 Shiller): Monthly Weinstein on Shiller 1871-2025.
  Headline (MA=10 months): framework beats B&H on every dimension over
  155y. Sharpe ~2× B&H, MaxDD -34% vs -85%, 10.3× more wealth.
- **PR #1209** (data): Kenneth French 49-Industry daily fixture
  (1926-2026, 26,212 days × 49 industries).
- **PR #1211** (M2 strategy): Daily-bar Weinstein 49-industry rotation.
  100y headline: Sharpe **0.81**, CAGR **13.55%**, MaxDD **-64%**, β
  **0.708**. 1970s **0.99 Sharpe vs B&H 0.48** (crushes stagflation).
- **PR #1212** (M1 follow-up): MA-window unit-tag fix
  (`Days | Weeks | Months` variant); default `Weeks 30` matches book.
- **PR #1213** (M2 writeup): Decision-tree resolution — M3 **DEFERRED**
  per plan's own gating logic (M3 only load-bearing if rotation
  collapses; rotation does NOT collapse in any tested regime).

### Bayesian sweep infrastructure (#1196)

- **PR #1196** (plan, merged): Wire `Spec.objective` into walk-forward
  scorer (3-PR plan).
- **PR #1214** (PR-1 of #1196): Signature plumbing complete. Sharpe
  path byte-identical. Non-Sharpe objectives → `Status.Unimplemented`
  stub.
- **PR-2 of #1196 (TODO)**: ~300 LOC. Implement Composite + Calmar
  + TotalReturn + Concavity_coef scoring branches with 8 new tests.
  Load-bearing if V2 sweep also rejects.

### V2 Bayesian sweep (LAUNCHED — in-flight)

- Started ~09:30 PT 2026-05-20. PID 90733 in `trading-1-dev`,
  parallel=4. ETA ~20:50 PT (9pm) today.
- Spec: `spec_prod_v2.sexp` (widened bounds on 3 of 4 knobs that
  clustered at lower bound in v1).
- Walk-forward: `walk_forward_v2_baseline.sexp` (cell-E single
  variant; BO injects candidates per iteration).
- Baseline aggregate reused from `v1-winner-fullrun/aggregate.sexp`
  (cell-E rows pre-existing).
- Output target: `output-v2-parallel4/`.
- Log: `dev/logs/bayesian-prod-v2-parallel4.log`.

## P0 — Process V2 sweep result

Same recipe as v1. To check:

```sh
docker exec trading-1-dev pgrep -f bayesian_runner.exe
# Empty → sweep done. Output files at:
ls /workspaces/trading-1/dev/experiments/bayesian-production-sweep-2026-05-18/output-v2-parallel4/
# Expect: best.sexp, bo_log.csv, convergence.md, oos_report.md
```

### If sweep done

1. Read `oos_report.md` — built-in OOS verdict on holdout folds 27-30.
2. Read `best.sexp` for the 4 knob values.
3. Apply plan §6 promote-gate (5 axes): median composite ≥ baseline+0.05,
   no fold worse by >0.10, OOS Sharpe ≥0.50 every fold, MaxDD ≤baseline+5pp,
   n_trades within 2×. Note: only OOS axis is auto-computed.
4. Write `dev/notes/bayesian-prod-v2-result-2026-05-21.md`.

### If V2 PROMOTABLE

Follow `dev/plans/private-tuned-configs-repo-2026-05-18.md` — commit
to `dayfine/trading-configs-private`, open tracking issue here.

### If V2 REJECT

P0 becomes: implement PR-2 of #1196 (Composite scorer). Then re-run
sweep as V3 against the multi-objective scorer. This is the "v2 also
needs multi-objective scoring" branch of the original sweep plan.

## P1 — PR-2 of #1196 (Composite scorer)

Already-designed implementation work. Plan lives in main:
`dev/plans/wire-spec-objective-into-score-cell-2026-05-18.md`.

- ~300 LOC.
- Adds Composite-relative + single-metric-relative scoring.
- 8 new tests.
- Reference doc PR-1 (merged in #1214) as the plumbing prerequisite.

Run regardless of V2 outcome — if V2 promotes, PR-2 is still useful
for future tuning iterations. If V2 rejects, PR-2 unblocks V3.

## P2 — Hold-period deep-dive remaining probes

Per `dev/plans/hold-period-deep-dive-2026-05-19.md`:

- **P4** (per-stage hold dispersion): needs entry-stage data joined to
  hold-period distribution. Probably 1 day of data prep + analysis.
- **P5** (composite scoring): blocked on PR-2 of #1196.

## P3 — Defer/Park

- **M3 per-stock synthesis**: DEFERRED per M2 decision-tree (see
  `dev/notes/cross-cycle-validation-m2-result-2026-05-20.md`). Revisit
  only if V2 + composite scorer both fail to find a Pareto improvement.
- **Plan #1196 PR-3** (~50 LOC doc): drop CVaR from production-sweep
  doc + reword "median" → "mean". Low-priority cleanup; ship after
  PR-2 lands.

## Branch state (end of 2026-05-20)

- `main`: at PR #1196 (plan) + #1214 (plumbing) merged.
- No feature branches open. No drafts.
- Working copy: clean.

## Background processes to verify at session start

```sh
# V2 sweep alive?
docker exec trading-1-dev pgrep -f bayesian_runner.exe
# Cleanup sidecar?
docker exec trading-1-dev pgrep -af "find /tmp"
# Log tail
tail -50 /workspaces/trading-1/dev/logs/bayesian-prod-v2-parallel4.log
```

## Files of interest

- `dev/notes/cross-cycle-validation-m2-result-2026-05-20.md` — M2
  decision-tree resolution.
- `dev/notes/bayesian-prod-v1-result-2026-05-20.md` — v1 REJECT verdict.
- `dev/plans/wire-spec-objective-into-score-cell-2026-05-18.md` — PR-2
  design.
- `dev/plans/cross-cycle-weinstein-validation-2026-05-19.md` — full
  4-milestone plan, M3+M4 parked.
- `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.{ml,mli}` —
  PR-1 plumbing target for PR-2 implementation.
