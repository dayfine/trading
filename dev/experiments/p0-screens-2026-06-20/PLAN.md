# P0 lens-screens — reserved short sleeve (#1659) + vol-scaled stop (#1662)

**Date:** 2026-06-20. **Origin:** `next-session-priorities-2026-06-20.md` P0.
Both levers landed default-off 2026-06-19; this is the cheap read-only
lens-screen that decides whether either earns a WF-CV surface + grid.

**Verdict calibration (`mechanism-validation-rigor` / `screen-rigor`):** a lens
screen rejects *prioritization*, not the mechanism. Legitimate outputs:
"promising → escalate to WF-CV" or "no-build decision (+ why)". NOT "proven" /
"decisively rejected".

## Window

Deep **1998-2026** top-3000 PIT-1998 (Cell-E), the only window spanning a
bear-dominated macro regime (dot-com bust + GFC) — where both stops (disaster to
dodge) and shorts (Stage-4 leg pays) actually bite. Bull-only 2011 would
under-test both. Grid (if escalated) adds the period × universe cells later.

## P0b — vol-scaled stop (`stops_config.vol_scaled_stop_atr_mult`)

Long-only deep. Floor on installed-stop distance becomes
`max(installed_stop_min_pct, mult * ATR/entry)` → volatile names get a wider
stop floor (whipsaw reduction at source).

- **Baseline (mult=0, off):** `scenarios-2026-06-18-232354/cell-e-top3000-1998-deep`
  (reuse; 1062 trades, wall 4208s).
- **Variants:** mult ∈ {1.0, 1.5, 2.0} — `p0-screens-2026-06-20/volstop-mult{10,15,20}.sexp`.

**Question (the asymmetry weekly-close #1655 failed):** does the `stop_loss`
exit row's **forgone-upside shrink while disaster-dodged holds**, net
value-add improve? Plus top-level return / Sharpe / MaxDD vs baseline.
Grade horizon 26w (matches the deep stop read `grade-deep-26w.md`).

## P0a — reserved short sleeve (`short_sleeve_fraction`)

Long-short deep (margin on, short_min_price 17). Reserves `fraction * PV` as a
short-only cash budget so shorts are *reached* (diagnosed crowd-out:
1,662 slots offered / 37 entered / 0 rejected over 28y).

- **Baseline (sleeve=0):** `scenarios-2026-06-19-065941/cell-e-top3000-1998-longshort`
  (reuse; 1165 trades, wall 4389s).
- **Variants:** fraction ∈ {0.10, 0.20, 0.30} — `p0-screens-2026-06-20/sleeve-0{10,20,30}.sexp`.

**Question:** with the sleeve funded, do the now-numerous shorts add a **real
offsetting / DD-reducing leg**, or churn at ~breakeven (capital reserved for a
leg that doesn't pay = drag)? Measure: (a) short-trade count + win-rate + net
PnL contribution, (b) top-level return / Sharpe / **MaxDD** vs sleeve=0 baseline
(the offset shows up as DD reduction), (c) lens grade of the short round-trips.

## Mechanics

- Batch run: `scenario_runner --dir dev/backtest/p0-screens-2026-06-20
  --snapshot-dir /tmp/snap_top3000_1998_2026_v2 --fixtures-root / --parallel 1`
  → output `dev/backtest/scenarios-2026-06-20-062510/<name>/`.
- Grade each: `decision_grading_bin --scenario-dir <out>/<name>
  --snapshot-dir /tmp/snap_top3000_1998_2026_v2 --grade-horizon 26
  --out <name>-grade.md`.
- Top-level metrics from each `<name>/summary.sexp`.

## Decision rule (per lever)

- Lens shows genuine asymmetry/offset improvement that's distribution-robust
  (not one-trade) → **escalate to WF-CV** as a `Variant_matrix` axis.
- ~Breakeven / coin-flip / one-trade artifact → **no-build decision**, record the
  *why*, keep default-off as an axis (`experiment-flag-discipline`).

## Results — FILLED AFTER RUNS (see FINDINGS.md)
