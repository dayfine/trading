# Next-session priorities — 2026-05-12

Overnight session 2026-05-11 → 2026-05-12. ~4h budget; finished what fit on
the CPU-saturated container.

## What landed

| PR | Type | State |
|---|---|---|
| #1043 | `feat(screener): add volume_ratio_exclude_range knob` | OPEN, CI green, awaiting QC |
| #1044 | `ops: overnight sweep scenarios + reports` (data + reports) | OPEN, CI re-running on push |
| #1045 | `ops(status): reconcile post 2026-05-11` (status flips) | OPEN, CI green |

PR #1043 = Action #2 from `entry-signal-quintiles-2026-05-11.md`.
PR #1044 includes 2 sweep reports + intra-friday recycling note.
PR #1045 flips `all-eligible` + `cost-tracking` to MERGED, narrows
`experiments` to remaining stability/turnover-metrics catch-all.

## Sweep results

### Holding-period sweep (16 cells planned, 11 completed, 5 OOM-crashed)

Report: `dev/experiments/holding-period-sweep-2026-05-12/report.md`.

**Headline: Cell E baseline (s1-l2) is near-optimal.** No grid cell strictly
dominates baseline on (Sharpe AND DD AND return AND WR). Strong negative
result: capital-recycling intuition that aggressive rotation would unlock
performance is FALSIFIED at the strategy-level metric layer.

Notable:
- s0-l2 == s1-l2 (byte-identical) → stage3_h is a no-op when laggard_h=2;
  stage3 force-exit feature **never fires** at baseline laggard cadence.
- Tightest DD (17.27%) was s3-l4 with Sharpe 0.82 — marginal; not worth
  promoting.
- Highest return (511%) was s3-l3 with Sharpe 0.58 + DD 48% — concentration
  cliff, validation flagged it.

### Entry-caps 3-arm sweep (3/3 done)

Report: `dev/experiments/entry-caps-2026-05-12/report.md`.

**Headline: `max_score_override=79` is NOT a clean win.** Q5 cap inverts
the risk profile:

| Arm | Return | Trades | WR | Sharpe | MaxDD |
|---|---:|---:|---:|---:|---:|
| A baseline | 374% | 768 | 39.5% | **0.85** | **18.4%** |
| B cap=79 | 405% | 1504 | 48.1% | 0.59 | 52.1% |
| C cap=79+stop=0.10 | (=B; bug) | (=B) | (=B) | (=B) | (=B) |

Mechanism: capping Q5 forces strategy out of "ride winners" regime into
"high-frequency rotation on Q3-Q4 candidates". Avg hold collapses 46d → 20d.
Trade count doubles. Stop-loss exits jump from baseline rate to 86% of all
exits. WR boost (+8.7pp) is real but PF stays flat at 1.60 — same
per-trade edge, more whipsaw.

### Intra-Friday recycling diagnostic (P5)

Note: `dev/notes/intra-friday-recycling-2026-05-12.md`.

**Headline: 59% intra-Friday recycling rate; main gap is 45% of Fridays
produce ZERO entries.** Capital-throughput dominant lever remains
per-position size (`max_position_pct_long=0.14` is already Sharpe-optimal
per 2026-05-10 sweep), not holding-period or entry cadence.

## Bug filed (not coded, just documented)

`Backtest.Runner._apply_overrides` doesn't deep-merge multiple overlays
targeting the same top-level field. Repro case in entry-caps report §"Bug
filed". Workaround: bundle into one overlay sexp.

## Skipped from overnight plan

- **Block 4: 81-cell flagship `screening.weights.*` grid** — out of budget.
  Spec written at `dev/experiments/grid-screening-weights-2026-05-12/spec.sexp`,
  ready to run. Will close `tuning` track when paired with Block 5.
- **Block 5: T-B convergence cross-check** — out of budget. After Block 4.

## Next session priorities

### P1 — Merge overnight PRs

#1043, #1044, #1045 all open + CI green (modulo #1044 re-running). Inspect
QC, merge if OK. PR #1043 is the only one with code; #1044 + #1045 are
data/docs only.

### P2 — Run the 81-cell flagship grid_search (Block 4 deferred)

Spec at `dev/experiments/grid-screening-weights-2026-05-12/spec.sexp`.
Wall ~2h on smoke catalog (3 scenarios × 81 cells). Closes M5.5 T-A
acceptance criterion if best-cell Sharpe > baseline (rs=1.0, vol=1.0,
break=1.0, sec=1.0). Local-only.

```
dev/lib/run-in-env.sh dune exec trading/backtest/tuner/bin/grid_search.exe -- \
  --spec /workspaces/trading-1/dev/experiments/grid-screening-weights-2026-05-12/spec.sexp \
  --out-dir /workspaces/trading-1/dev/experiments/grid-screening-weights-2026-05-12
```

Then T-B convergence cross-check (Block 5; ~30min wall). Together they
close `tuning` track.

### P3 — Re-run 5 OOM-crashed holding-period cells at --parallel 2

Cells: `s0-l1, s0-l3, s1-l3, s2-l1, s2-l4`. Lower parallelism so they fit
in container memory. Likely fills in matrix without changing the verdict
(baseline near-optimal), but completes the data set.

### P4 — Fix runner `_apply_overrides` deep-merge

Multiple overlays targeting the same top-level field don't compose. See
entry-caps report §"Bug filed" for repro. Likely in
`trading/trading/backtest/lib/runner.ml:_merge_sexp` — inspect the
fall-through behavior on inner records. Until fixed, sweep authors must
bundle multiple field overrides for the same top-level key into one
overlay sexp (workaround documented in entry-caps report).

### P5 — Q5-cap refinements (after P4)

The Q5-cap finding is real but the hard-cap implementation is wrong.
Three refinements worth testing once the runner bug is fixed:
- E5: soft penalty in `Screener.scoring_weights` (downgrade Q5 features
  rather than reject candidates)
- E6: Q5 cap × wider initial_stop_pct grid
- E7: Q5 cap conditional on macro_trend = Bullish

### P6 — `volume_ratio_exclude_range` 3-arm test (after #1043 merges)

Same template as entry-caps but with vol_excl=[2.5, 3.0]. Per the quintile
note, this is the other entry-signal lever. Expect similar regime-shift
risk to the Q5 cap — needs same careful before/after.

## Container state observations

- 5/16 holding-period cells crashed mid-run at --parallel 5 with 7.9 GB
  total memory (each cell needs ~1.7 GB). At --parallel 5 + competing
  goldens-broad sweep (which was running concurrently early-session) the
  container OOMed during heaviest phase.
- After competing sweep ended, --parallel 3 entry-caps completed cleanly
  in ~50 min wall.
- Recommendation for future overnight planning: budget `--parallel 3` as
  the SAFE ceiling on this container; `--parallel 5` only if no competing
  workload.

## Files referenced

- `dev/experiments/holding-period-sweep-2026-05-12/{README,report}.md` +
  16 scenarios + 11 completed cells under
  `dev/backtest/scenarios-2026-05-11-230718/`
- `dev/experiments/entry-caps-2026-05-12/{README,report}.md` + 3 scenarios
  + 3 completed cells under `dev/backtest/scenarios-2026-05-12-021705/`
- `dev/experiments/grid-screening-weights-2026-05-12/{README,spec}.sexp`
  (P2 ready-to-run)
- `dev/notes/intra-friday-recycling-2026-05-12.md` (P5 closed)
- `dev/notes/cell-e-candidate-supply-bottleneck-2026-05-11.md` (origin
  hypothesis)
- `dev/notes/entry-signal-quintiles-2026-05-11.md` (origin Q5 finding)
