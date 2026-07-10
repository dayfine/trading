# Honest-tradeable deep baseline — top-3000 2000-2026, overlay + stale-exit armed (2026-07-10)

User-approved (2026-07-09 remediation sign-off): the deep number of record is
now measured with the REALISM dials armed — liquidity overlay
(`min_entry_dollar_adv 1e6 / min_hold_dollar_adv 5e5`, #1760) + stale-exit
(5d, #1487) — on merged main (364 basis, round-trip pairing fix #1906, floor
default-off #1910; neutral flip #1909 inert here, long-only). Same base
otherwise: `top3000-2000-2026-catstop` (0.14 conc, catstop 0.10), snapshot
warehouse `/tmp/snap_top3000_1998_2026`.

## Result — realism arming IMPROVES everything (and that passes scrutiny)

| metric | un-armed (2026-07-09) | ARMED (this run) | SPY TR same window |
|---|---|---|---|
| Total return (MTM) | +2062.6% | **+6889.6%** ($69.9M) | +686.6% |
| Realized-basis end equity | ≈ $5.75M (+475%, 6.9%/yr) | **≈ $17.0M (+1600%, ~11.4%/yr)** | 8.15%/yr |
| Sharpe / Sortino / Calmar | 0.417 / 0.449 / 0.208 | **0.806 / 1.292 / 0.431** | |
| MaxDD / Ulcer | 59.4% (fake) / 26.5 | **40.6% / 15.0** | |
| trades / win% | 984 / 35.9 | 1137 / 36.9 | |
| force liqs / stale-hold events | 5 / many (zombies held) | 2 / 9 (exited) | |

**First deep path where REALIZED beats TR-SPY** (≈11.4%/yr vs 8.15%/yr).

## Why it improves (decomposed — not a single-event artifact)

Year-end equity ratio (armed/un-armed): 1.02 (2000) → 1.20 (2004) → 2.15
(2008) → ~2.1 flat (2010-13) → 1.76-2.2 (2016-20) → 3.23 (2024-26).
**Gradual, persistent, sign-stable in every sub-period** (one convergence
year, 2014, where the un-armed path's winners briefly caught up). This is the
distributed shape, not luck: the overlay is a QUALITY filter, not just a
realism filter —

1. Fake wins gated (APPB +$540k at $9.5k/day ADV never enters);
2. Zombie capital freed (IN1's $143k was dead 20 years un-armed; stale-exit
   recycles it);
3. Corrupt-bar names (MSZ class) never enter → no phantom NAV, no phantom DD;
4. The freed/redirected capital compounds in liquid names — where ALL the
   real fat-tail winners live (`project_trade_realism_liquidity`).

Re-derives the known structure from a new angle: junk holdings were pure
drag; the edge concentrates in liquid monsters (AXTI again: $51.7M terminal
MTM on the same 2025-06-28 @ $2.19 entry, position 3.4× larger because NAV at
entry was 3.4× larger).

## Caveats (screen-rigor)

- **Single path vs single path.** The gradual persistent shape is the robust
  kind, but start-date/fold robustness is the scoreboard's own rule — the
  honest next step is a WF-CV or rolling-start matrix with
  `liquidity_config.min_entry_dollar_adv {0, 1e6}` as the axis (it is one).
  Until then this is the honest-tradeable POINT baseline, not a fold-proven
  claim that "the overlay adds +X%/yr".
- Terminal MTM still AXTI-dominated ($51.7M of $66.8M OPV) — the realized
  split above is the honest bank.
- Overlay + stale-exit remain default-off flags; arming them here is a
  MEASUREMENT convention for the record run (realism, like the total-return
  comparator rule), not a default promotion.

## Reproduce

Staged scenario = the catstop golden + 2 overrides
(`liquidity_config ((min_entry_dollar_adv 1000000.0) (min_hold_dollar_adv 500000.0))`,
`stale_exit_after_days (5)`); snapshot mode; TRADING_DATA_DIR=test_data.
Raw outputs (gitignored):
`trading/dev/backtest/scenarios-2026-07-10-014052/top3000-2000-2026-honest-tradeable/`.
Log `/tmp/sweeps/honest-tradeable-v1.log`. Wall ~85 min.
