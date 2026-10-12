# index-hedge-screen-2026-10-12: index-short overlay screen on the record (N)

**Pre-registration:** `dev/plans/index-hedge-screen-2026-10-11.md`, CONFIRMED by the user and merged as `776e8d355`
(#3251). This directory applies it without changes, except for the operational choices listed below.

## Inputs

- **Base:** the record N, rb1 on the full NYSE A-D fixture (#3261). It has three salts:
  `dev/experiments/breadth-fix-rb1-2026-10-11/results/N-rb1-26-s{0,1,2}-v12-equity_curve.csv`. The run is total
  return with interest and dividends on, over 2000-01-03 → 2026-06-25.
- **SPY:** the host `data/S/Y/SPY/data.csv`, `adjusted_close` (total return, so the short pays dividends).
- **G1, SPY's weekly stage:** `results/spy-weekly-stage.csv`.
  - It is the `stage_chart.exe` replay of SPY over 1999-01-01 → 2026-06-26, using the default classifier on
    adjusted closes. This is the same replay the review pack uses for trade stages.
  - G1 is on in weeks whose stage is `Stage4`: price below a falling 30-week MA.
- **G2, G3, the macro gate:** `results/macro-N.csv`, the `trend` column of N's `macro_trend.sexp`. It is identical
  across salts, with 233 Bearish weeks.
- **Cash rate for the credit sensitivity:** `data/macro/tbill_3m_dtb3.csv`, minus 10 bp (the record's
  `cash_yield_fee_bp`).

## Overlay (as pre-registered)

`ln V*_T = ln V_T + Σ_t ln(1 − h · g_{t−1} · r_SPY,t) − borrow`

- h ∈ {0.25, 0.5, 1.0}.
- Borrow is 0.25 %/yr on the notional, charged daily.
- Primary: short proceeds earn no interest. Sensitivity: they earn DTB3 − 10 bp.

**Operational choices** (the plan leaves these open):

1. **Gate timing.** "Weekly and lagged one week" is implemented as follows: the gate on day t is the reading of the
   last week-end strictly before t. A reading at Friday's close applies from the next trading day. The `-lag1`
   sensitivity adds one more week.
2. **Drawdown.** Max drawdown is measured on the daily combined NAV, and so is the base's.
3. **Regimes.** The UP / MIXED / DOWN split of overlay P&L uses the pack's rule: weekly close vs the 30-week MA and
   the MA's 4-week slope, read at the same lagged week as the gate.

## Files

- `scripts/overlay.awk`, `scripts/run.sh`: run `run.sh` from the repo root to regenerate every `results/*.txt`.
- `results/summary-s{0,1,2}.txt` (primary), `-credit.txt`, `-lag1.txt`. Each row is one (gate, h) cell and gives:
  - days the gate is on, overlay log, combined log, and the delta vs base;
  - combined max drawdown and its delta vs base;
  - bear-period deltas and how many of the 3 bears it beats;
  - criteria flags c1–c3;
  - overlay log by regime.
- `results/years-s{0,1,2}.txt`: combined − base log by year at h = 0.5.
- `results/episodes.txt`: every gate episode with SPY's move and the h = 1 short log.

The reading (`## Results`) follows.
