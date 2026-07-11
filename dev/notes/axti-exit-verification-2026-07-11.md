# AXTI exit verification — extended window to 2026-06-26 (S1, 2026-07-11)

Executes S1 of `next-session-priorities-2026-07-11.md`: rebuilt the deep
warehouse to 2026-06-26 and re-ran the honest-tradeable record run
(`dev/notes/honest-tradeable-baseline-2026-07-10.md`) with the extended end,
to observe which exit branch reality takes on the AXTI monster.

## Answer: Branch B — still holding through the give-back

**AXTI is still OPEN at 2026-06-26** (entry 2025-06-28 @ $2.19, 652,229 sh,
MTM $45.8M at the $70.15 close). The trailing stop did NOT advance past the
mid-May pullback; the position rode the full $122 (mid-May peak) → $70
(June 22-26 slide) give-back — ~$34M of MTM foregone from the peak, ~43%
of the position's peak value.

Price path (closes): Apr-08 $53 → Apr-22 $87 → Apr-29 $71 (the April
shakeout) → May-13 $122 (peak) → May-20 $105 → Jun-11 $88 → Jun-18 $85 →
Jun-24 $70 → Jun-26 $70.15.

This is monster #4 from the 07-10 capture-quality reflection (parabola
give-back) playing out live in the record run: weekly-cadence Weinstein
mechanics hold a parabolic name until Stage-3/stop confirmation, and after a
36× run the stop/MA sits far below the parabola's peak. Consistent with the
07-10 session-log finding that single-specimen close/MA extension thresholds
are hindsight (the April-28 shakeout would have been trapped by them —
price dipped to $71 in April before the May leg to $122). Whether a
distribution-level `extension_stop` axis is worth building is exactly S2's
event-level screen — this specimen feeds it but cannot decide it.

## Extended-window record numbers (same conventions as 07-10)

| metric | end 2026-04-30 | end 2026-06-26 | SPY TR same window |
|---|---|---|---|
| Total return (MTM) | +6889.6% ($69.9M) | **+6885.1% ($69.9M)** | **+700.0%** (91.1286 → 728.99 adj) |
| Unrealized / OPV | $51.7M of $66.8M | $52.2M / $62.3M OPV | |
| Realized-basis end equity | ≈$17.0M (+1600%, ~11.4%/yr) | **≈$17.7M (+1670%, ~11.5%/yr)** | 8.17%/yr |
| Sharpe / Sortino / Calmar | 0.806 / 1.292 / 0.431 | 0.768 / 1.187 / 0.421 | |
| MaxDD / Ulcer | 40.6% / 15.0 | 41.3% / 15.0 | |
| trades / win% | 1137 / 36.9 | 1140 / 37.1 | |

- Topline FLAT over the extra 2 months (AXTI's MTM decline ≈ offset by the
  rest of the book + its own May run-up). MaxDD ticks up 40.6→41.3 — the
  new dip is AXTI-peak-relative (the same squeeze-MTM-DD shape as the GME
  window; the realized bank never saw it).
- **Realized still beats TR-SPY at the extended end** (~11.5%/yr vs
  8.17%/yr) — the honest-tradeable conclusion survives the give-back so far.
- Sharpe dips 0.806→0.768: two months of parabola unwind with no realizing
  mechanism = pure vol, zero realized delta. This is the measured cost of
  branch B to date, NOT proof an extension stop pays — S2 must answer that
  at the distribution level (the same mechanism that gives back $34M here
  is what let $2.19 become $122 instead of being trimmed at $8).

## Reproduce

- Warehouse: `build_scenario_snapshots -scenario test_data/backtest_scenarios/staging-honest-tradeable-ext/top3000-2000-2026-honest-tradeable-ext.sexp -csv-data-dir /workspaces/trading-1/data -fixtures-root test_data/backtest_scenarios -output-dir /tmp/snap_top3000_1998_2026_e0626`
  → window [1999-01-02, 2026-06-26], 2999 entries, verify 2999/2999 OK, ~30 min.
- Run: staged scenario (committed at
  `test_data/backtest_scenarios/staging-honest-tradeable-ext/`) = the catstop
  golden + honest-tradeable convention overrides (entry gate 1e6 — now the
  #1926 default anyway; min_hold 5e5; stale-exit 5d) + end 2026-06-26;
  `scenario_runner --dir /tmp/ht-ext --snapshot-dir /tmp/snap_top3000_1998_2026_e0626 --parallel 1 --no-emit-all-eligible`, ~95 min.
- Raw outputs (gitignored):
  `trading/dev/backtest/scenarios-2026-07-11-195158/top3000-2000-2026-honest-tradeable-ext/`.
- SPY TR: `data/S/Y/SPY/data.csv` adjusted_close 2000-01-03 (91.1286) →
  2026-06-26 (728.99).

## Post-#1926 context note

The realism flip merged earlier today (#1926) makes the entry gate + 5d
stale-exit the DEFAULTS; this run still passes all three dials explicitly
(incl. the not-flipped `min_hold_dollar_adv 5e5`) per the record-run
measurement convention, so it remains directly comparable to the 07-10 line.
