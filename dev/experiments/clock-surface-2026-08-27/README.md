# clock-surface — entry_order_max_rest_weeks {0,13,26,52,156} on two broad cells (#2405)

The re-flip test #2405's own record demands: the clock measured as a SURFACE
(value re-opened, not assumed — 26 was never derived), multi-cell, with the
fill-model default pair ON (#2569) so every backtest grows resting tickets.
USER approval-in-principle 2026-08-25; fill-model decision 2026-08-26.

## Cells

| cell | lineage | window × universe | why |
|---|---|---|---|
| **B** | `broad5y-00-core` (ladder-v4 cell-00) | 2019-01-02..2023-12-29 × top-3000 PIT-2019 | fast read; the window family where the −40.91pp sp500 episode lived |
| **A** | `record-baseline` (2026-08-24 canonical) | 2000-01-01..2026-06-26 × top-3000 PIT-2000 | macro-diverse (dot-com + GFC); the 26y record convention |

Both cells: one-knob arm diffs (`entry_order_max_rest_weeks` only), salt 0,
split-safe warehouse `/tmp/snap_top3000_dedup_v5thin_adj`, `--parallel 1`
per run. Universe discipline: both cells broad (top-3000) — no sp500 cell.

## Fresh nulls (arm 0), not tripwires

The committed baselines predate two default-moving merges: #2561 (RS
`lookback_bars` 52→56, classifier now live) and #2569 (`enable_sim_entry_stoplimit`
+ `entry_extension_max_pct` pair — pinned in these specs anyway). So arm 0 of
each cell is a FRESH NULL at build `90dfd6e97`; a delta vs record-baseline
731.64 / broad5y 281.71 is the build moving, not the clock. All arm
comparisons are within-cell against THIS run's arm 0.

## Pre-registered decision rule

1. **Top-lines are gated by the noise floors**: 26y ≈ 132.5pp (3-salt, old
   basis — treat as order-of-magnitude), broad-5y per
   `rt-freshness-broad5y-2026-08-20/README.md`. No top-line gap below the
   floor is interpretable on its own.
2. **The verdict evidence is the paired trade-level dissection** (join
   `position_id`; `symbol|entry_date` cross-arm): for each arm vs arm 0,
   the removed-fills cohort (rest > w) must reproduce the shape of the
   committed 2026-08-16 bucket table (rest >26wk: 89 fills, −349,132 on the
   record base) — a net-negative removed cohort at the chosen w = the
   mechanism working; a net-positive removed cohort = the SMCI reading wins
   in that window and the arm is a tail-tax there.
3. **Boundary location**: the bucket table puts the sign flip inside
   14–52wk (14–26wk +82,266; 27–52wk −148,226). If the surface agrees
   (13 too tight / 52 too loose / 26 or between robust in both cells),
   the re-flip PR proposes the robust value; if the cells disagree on
   sign at every w, record REJECT-as-default / keep-as-axis and stop.
4. **SMCI / freeze_entry_at_first_breakout adjudication**: locate SMCI (or
   its analogue) in cell A's arm diffs; classify its entry E as
   stale-screen-harvest vs legitimate-base per the #2405 record. This
   informs the separate freeze knob question; it does not gate the clock
   verdict (the base-broken measurement already showed 79/89 long-rest
   fills were structurally broken).
5. Promotion (default flip 0→w) additionally requires the
   `config-default-blast-radius` paired-golden protocol on the flip PR —
   the goldens_affected_check will now correctly FAIL affects-all/default-flip
   (#2575) and the paired table + `paired-run-done` label resolve it.

## Mechanics

- Pinned worktree `.claude/worktrees/sweep-clock2405` @ `90dfd6e97`.
- Specs staged at `/tmp/clock2405-run/specs` (outside any VCS tree).
- Per-arm artifacts exported to `.sweep-output/clock2405/` (bind-mount) as
  `<arm>-{actual.sexp,trades.csv,params.sexp}`; committed under `results/`
  when the surface completes (never read numbers from the chain log).
- Chain log: `/tmp/clock2405-chain.log` (host).

## Results

(pending)
