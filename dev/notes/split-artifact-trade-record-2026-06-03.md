# Split-straddling trades mis-recorded in trade metrics (returns are SAFE)

**Date:** 2026-06-03 · Step 1 of the stage-accuracy plan (prerequisite to the
`late`-exposure dial, since it would otherwise corrupt the test harness).

## Symptom

The production-deep run's worst-$ "losses" cluster on split dates and look fake:

| trade | entry | exit | qty | recorded pnl | split |
|---|---|---|---|---|---|
| NKE | 2006-09-30 @ 88.54 | 2007-04-21 @ 53.45 | 5988 | **−39.6%** | 2:1 on 2007-04-03 |
| ISRG | 2021-05-15 @ 823.38 | 2021-10-16 @ 332.03 | 1553 | **−59.7%** | 3:1 on 2021-10-05 |
| EL | 2011-12-03 @ 117.52 | 2012-02-04 @ 55.47 | 3396 | **−52.8%** | 2:1 on 2012-01-23 |
| DISCA | 2014-08-02 @ 85.02 | 2014-08-08 @ 41.04 | 13801 | **−51.7%** (6 days!) | ~2:1 |

The exit price is the *post-split* raw price; the entry price + quantity are the
*pre-split* originals. NKE's real result: 5988 @ 88.54 ($530k) → 11976 (post-2:1)
@ 53.45 ($640k) = **+20.7%**, not −39.6%.

## Root cause — `metrics.ml:74-92` `_make_trade_metric`

```
entry_price = entry.price;     (* original entry-leg fill, pre-split *)
quantity    = entry.quantity;  (* original, pre-split *)
exit_price  = exit.price;      (* post-split *)
pnl = (exit_price - entry_price) * quantity   (* mismatched bases *)
```

The trade record pairs an entry fill-leg with an exit fill-leg and computes pnl
directly from them, with **no cumulative split-factor adjustment over the holding
period**. When ≥1 split occurs mid-hold, entry basis (pre-split) and exit basis
(post-split) are inconsistent.

## Severity — scoped, NOT a returns bug

`split_handler.apply_to_position` (and `apply_events` on the broker portfolio)
**do** scale held positions on the split day (qty ×factor, entry_price ÷factor,
cost basis preserved), updating both broker and strategy views. So:

- **SAFE:** equity curve, total return, MaxDD, Sharpe, Calmar, Sortino — all
  computed from portfolio NAV, which is split-adjusted. The barbell P0 numbers
  (918% / 237.6%) and the golden re-pin (#1434) all stand.
- **CONTAMINATED:** per-trade `pnl_dollars`/`pnl_percent` in `trades.csv`, and the
  trade-level aggregates derived from them — **win_rate, profit_factor,
  avg_win/avg_loss, largest_loss** — plus the per-symbol **autopsy harness**
  (buckets per-trade outcomes). Split-straddling winners are booked as ~−50%/−67%
  losers, understating win_rate / PF.

Affected trades ≈ the count of split events straddling a held position (16 split
events total in the deep run; a handful straddle holds).

## Fix spec

Adjust the entry leg to the exit basis (or vice versa) by the cumulative split
factor between `entry_date` and `exit_date` when building the trade metric.

Two options:
1. **At record-construction (`_make_trade_metric`)**: thread the per-symbol split
   events (already detected — see `split_handler.detect_for_symbol` /
   `Split_event.t`) and divide `entry.price` by — and multiply `entry.quantity`
   by — the product of factors with `entry_date < split_date ≤ exit_date`.
2. **At split-application time**: also scale the *recorded entry fill-leg* used
   for trade pairing, in lockstep with `apply_to_position` (which already scales
   the live Holding). More consistent but requires the fill-leg history to be
   mutable/addressable from the split path.

Option 1 is the smaller, more local change. TDD: a unit test with a position held
across a 2:1 split asserting the trade pnl uses the adjusted basis (e.g. the NKE
shape → ~+20.7%, not −39.6%). Then re-run production-deep and confirm win_rate /
profit_factor rise and the fake −40%/−60% trades disappear from `trades.csv`.

This is a `trading/trading/simulation` (core-ish) correctness fix → proper TDD +
QC. Returns don't move, so no golden re-pin needed.
