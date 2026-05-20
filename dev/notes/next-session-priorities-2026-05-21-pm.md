# Next-session priorities (post 2026-05-20 PM)

Written end of session 2026-05-20 22:48 PT (post-V2-sweep). Supersedes
`next-session-priorities-2026-05-21.md` which was written BEFORE V2
finished.

## TL;DR

V2 Bayesian sweep landed and **REJECTED** on 5-axis promote-gate. The
diagnosis is sharp: BO never improved past iter-1 because the
`-10×gate_fail` penalty made the search surface flat. Path forward is
V3 with the **Composite scorer** (shipped today) + tighter bounds.

## Today's work (13 PRs merged)

### Cross-cycle Weinstein validation
- **#1207** Shiller M1 (1871-2025, MA=10 months = +1.59pp CAGR vs B&H, Sharpe 2×)
- **#1209** French 49-Industry daily fixture (1926-2026)
- **#1211** M2 rotation strategy (Sharpe 0.81 / CAGR 13.55% / MaxDD -64% / β 0.708 over 100y)
- **#1212** MA-window unit-tag fix (default `Weeks 30`)
- **#1213** M2 writeup → **M3 DEFERRED** per decision-tree

### Bayesian sweep stack (#1196)
- **#1196** plan
- **#1214** PR-1 plumbing (Sharpe byte-identical)
- **#1216** PR-2 Composite + Calmar + TotalReturn + Concavity_coef
- **#1217** PR-3 doc amend (drop CVaR, median→mean)

### Hold-period deep-dive
- **#1219** P4 per-stage analysis (Stage-mis-classification hypothesis FALSIFIED — 100% Stage2; inverted score-quartile P&L surfaced)
- **#1220** P5 cadence-scorer infra (`AvgHoldingDays` weight in Composite, design B symmetric)

### Operations
- **#1215** handoff (now stale; this doc supersedes)
- **#1222** V2 sweep REJECT verdict

## V2 result (REJECT)

Full verdict at `dev/notes/bayesian-prod-v2-result-2026-05-21.md`. Headline:

| Axis | Result |
|---|---|
| 1. Mean Sharpe ≥ baseline+0.05 | **PASS** (+0.245 vs cell-E) |
| 2. No fold worse by >0.10 Sharpe | **FAIL** (9 bad folds vs V1's 6) |
| 3. OOS Sharpe ≥0.50 every fold | **FAIL** (fold-029 = -0.996) |
| 4. MaxDD ≤baseline+5pp every fold | **FAIL** (fold-017 = +5.41pp, NEW regression) |
| 5. N_trades within 2× baseline | BORDERLINE |

V2 winner (iter-1 random sample — BO never improved):
- `max_position_pct_long = 0.061`
- `max_long_exposure_pct = 0.330` ← too low; hurt trending years
- `initial_stop_buffer = 1.072` ← too wide; caused fold-017 MaxDD blowout
- `installed_stop_min_pct = 0.114`

Mechanism: widened V2 bounds let exposure drop too far; widened initial
stop sacrificed risk discipline. BO stuck at iter-1 because gate-fail
penalty (-10) dominated the search surface.

## P0 — V3 sweep with Composite scorer + tighter bounds

The infrastructure for this landed TODAY. Just need to:

1. **Write `spec_prod_v3.sexp`**:
   ```sexp
   ((bounds
     (("portfolio_config.max_position_pct_long" (0.04 0.15))
      ("portfolio_config.max_long_exposure_pct" (0.45 0.85))   ; tightened lower bound (was 0.30)
      ("initial_stop_buffer" (1.00 1.05))                       ; tightened upper bound (was 1.10)
      ("screening_config.candidate_params.installed_stop_min_pct" (0.06 0.13))))
    (acquisition Expected_improvement)
    (initial_random 10)
    (total_budget 60)
    (seed (2026))
    (n_acquisition_candidates ())
    (objective
     (Composite
      ((SharpeRatio 0.40)
       (CalmarRatio 0.30)
       (MaxDrawdown -0.10)
       (AvgHoldingDays 0.10))))    ; cadence term per PR #1220 design B
    (scenarios ())
    (holdout_folds (27 28 29 30)))
   ```

2. **Re-precompute baseline aggregate** — V1's baseline was made before
   #1220 added `avg_holding_days` to `variant_stability`. Per the QC
   behavioral memo on #1220: pre-P5 baseline aggregates have
   `[@sexp.default Float.nan]` for avg_holding_days, which would
   NaN-poison the Composite-with-AvgHoldingDays scorer. Run cell-E
   baseline through `walk_forward_runner.exe` against the post-#1220
   build to get a fresh aggregate with the new field populated.

3. **Launch V3** at parallel=4. Wall: ~11-12h (same as V1/V2).

4. **Apply 5-axis gate** per dev/plans/bayesian-production-sweep-2026-05-18.md §6.

## P0.5 — Consider checkpointing FIRST (task #36)

Per memory `project_bayesian_sweep_checkpoint_needed.md`. V2 lost
~5h to power-loss-induced restart. If V3 hits the same, that's
another wasted session. Recommend: add incremental `bo_log.csv`
write-out + BO state persistence to `bayesian_runner_runner.ml`
BEFORE launching V3. ~200-300 LOC; 1 session of work.

**Tradeoff:** Checkpointing first delays V3 by 1 day but eliminates
restart-from-scratch risk. If V3 ETA is during a stable power window
(e.g. daytime), skip and launch directly.

## P1 — Run cadence-aware V3 (after baseline V3 lands)

The Composite-with-AvgHoldingDays sweep tests whether longer
hold-periods improve risk-adjusted return. Same wall as V3 baseline.

Sequence: V3 baseline (Composite) → analyze → V3 cadence (Composite
+ AvgHoldingDays).

## P2 — Per-stage analysis followup (PR #1219 surfaced finding)

P4 analysis found **inverted score-quartile P&L**: Q1 (lowest score,
&lt;60) → mean 1.71% P&L / win-rate 42.6% / hold 43d; Q4 (highest
score, ≥75) → 0.74% / 33.8% / 36d. If this replicates on V3 winner's
trade log, suggests inverting or removing the score gate is worth a
follow-up experiment. Cheap analysis — 1 hr.

## P3 — Defer / Park

- **M3 per-stock synthesis** — DEFERRED per M2 decision-tree.
- **M4 CRSP access** — blocked on Morningstar institutional terms.
- **Hold-period P5 cadence-aware sweep** — gated on V3 baseline lander.

## Branch state (end of 2026-05-20)

- `main`: at PR #1222 (V2 result writeup) merged.
- No open PRs. No drafts. Working copy clean.

## Background processes

Cleanup sidecars from V1/V2 sweeps should be GC'd. To verify:
```sh
docker exec trading-1-dev pgrep -af "find /tmp"
# Should match the cleanup sidecar pattern; will exit cleanly
# once bayesian_runner.exe is gone (the `while pgrep` loop).
```

## Files of interest

- `dev/notes/bayesian-prod-v2-result-2026-05-21.md` — V2 verdict (REJECT)
- `dev/notes/cross-cycle-validation-m2-result-2026-05-20.md` — M2 decision-tree
- `dev/notes/hold-period-p4-per-stage-2026-05-20.md` — P4 findings
- `dev/plans/wire-spec-objective-into-score-cell-2026-05-18.md` — #1196 plan (3 PRs all shipped)
- `dev/plans/hold-period-deep-dive-2026-05-19.md` — P1+P3+P4 done; P5 unblocked
- `dev/experiments/bayesian-production-sweep-2026-05-18/v2-winner-fullrun/` — V2 full-run output
- `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.{ml,mli}` — Composite scorer (PR-1+PR-2+P5 cadence all landed)
