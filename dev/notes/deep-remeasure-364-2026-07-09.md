# Deep top-3000 re-measure on the 364 (RS-honest) basis — 2026-07-09

The user-directed overnight run from `next-session-priorities-2026-07-08-PM.md`
(§End-of-session overnight run). First deep top-3000 measurement on the
warmup-364 basis (#1890); replaces the stale 210-basis references (917.9% /
+1552%).

**Scenario:** `goldens-sp500-historical/top3000-2000-2026-catstop.sexp` —
top-3000-2000 PIT, 2000-01-01..2026-04-30 (26.3y), long-only, Cell-E 0.14
concentration, catastrophic_stop 0.10, stage3-force-exit hyst-1, laggard hyst-2.
Snapshot mode against the rebuilt `/tmp/snap_top3000_1998_2026` (364-window,
2999 snaps). Liquidity overlay OFF, stale-exit flag OFF (defaults). Wall 73 min.

## Headline vs honest split

| measure | value | per-yr |
|---|---|---|
| Total return (MTM) | **+2062.6%** ($21.63M) | 12.4% |
| — of which terminal unrealized MTM | $15.88M (AXTI alone $15.3M) | |
| **Realized-basis end equity** (cash + open cost basis) | **≈ $5.75M ≈ +475%** | 6.9% |
| SPY TOTAL-RETURN same window (adj close 91.13→716.81) | **+686.6%** | 8.15% |
| SPX raw price same window | +395.4% | 6.3% |
| Sharpe / Sortino / Calmar / Ulcer | 0.417 / 0.449 / 0.208 / 26.5 | |
| Trades / win% / avg hold | 984 / 35.9% / 47.8d | |
| Force liqs | 5 (all per-position; **0 portfolio-floor**) | |

Same shape as the 28y broad block in `DEEP_RESULTS.md`: the MTM headline is one
open fat-tail monster (AXTI, entered 2025-06-28 @ $2.19, marks $79.22 = $15.3M
of the $20.1M OPV); the realized number sits **below TR-SPY**. The RS-honest
basis lifts the deep broad number a lot (210-basis 28y long-only was +721%
MTM / this 26y run is +2063% MTM) but does not change the honest structural
conclusion: realized < TR-SPY, edge concentrated in the fat tail.

## MaxDD 59.4% is an artifact — MSZ corrupt bars (new ELCO-class instance)

The reported MaxDD (peak 2014-08-15) traces to **recurring corrupt one-day bars
in MSZ**, a delisted micro-cap held 2014-08-02→2015-01-10 (141,467 sh @ ~$1.90):

- 2014-08-15 bar: 1.90 → **25.32/25.38/25.28/25.36** → 1.90 next day (13.3×,
  adjusted_close spikes identically → raw EODHD artifact, in the warehouse too).
- Same spike-revert on 2014-11-11, 2014-12-24+26, 2014-12-31, 2015-01-06 —
  each a one/two-day +130-140% NAV blip ($2.3M → $5.6-5.8M → back).
- Realized MSZ P&L was ordinary (+$63.7k); the damage is measurement-only
  (phantom NAV peaks → phantom drawdowns).

**Despiked (11-day-median filter) MaxDD = 50.3%**, peak 2021-02-09 → trough
2025-05-14: a REAL 4-year underwater stretch from the meme-era MTM peak
($12.3M Feb-2021 → ~$6.1M May-2025), followed by the AXTI 2025-26 moonshot.
That is the honest tail picture at 0.14 concentration on this basis.

Follow-ups this suggests:
1. **Liquidity overlay validation case #2** — MSZ at ~$60k/day dollar-ADV would
   be entry-gated by the default-off overlay (#1760), removing both the phantom
   DD and the position. (ELCO was case #1, short side; MSZ is long side +
   corrupt-bar flavor.)
2. **Data-quality screen** on the warehouse: one-day ≥5× spike-revert bars in
   sub-$5 names are detectable mechanically; worth a small audit exe before the
   next deep re-baseline. Filed as a follow-up in the P1 track, not built.

## Zombie stale holds (stale-exit flag OFF)

5 open "positions" at run end are delisted zombies marked at last close: IN1
(last bar 2005-02-25!), BVSN (2020), VIAS (2014), MGI, DSPG. The default-off
stale-exit flag (#1487) exists for exactly this; their residual marks are small
vs AXTI but nonzero. Any future promoted-config deep run should consider arming
it alongside the liquidity overlay for the honest-tradeable variant.

## Relative-verdict sanity

Nothing here re-litigates ledger verdicts (baseline and variants were equally
RS-starved pre-364; relative comparisons stand). This run refreshes the
ABSOLUTE topline only. Per the 2026-07-08 rule: do not mix pre-07-08 absolute
numbers with post-07-08 runs.

## Reproduce

```bash
docker exec -d trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && \
  export TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data && \
  ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
    --dir <staged dir with top3000-2000-2026-catstop.sexp> \
    --snapshot-dir /tmp/snap_top3000_1998_2026 --parallel 1 --no-emit-all-eligible'
```

Raw outputs (gitignored): `trading/dev/backtest/scenarios-2026-07-09-032112/top3000-2000-2026-catstop-deep/`.
Note the fixtures-root gotcha: without `TRADING_DATA_DIR=test_data` the
scenario's `universe_path` resolves against `data/backtest_scenarios` and
crashes (first launch attempt did exactly that).
