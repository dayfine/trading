# 16y Long-Short Portfolio_floor Cascade Investigation (post-PR #1052)

Scenario: `dev/backtest/scenarios-2026-05-12-194906/sp500-2010-2026-longshort-historical/`.
Cascade dates: **2025-04-17, 2025-05-05, 2025-05-19** (13 Portfolio_floor events; +1
unrelated DISCA Per_position on 2014-08-07).

## 1. Macro transitions in 2025

`macro_trend.sexp` is sparse — it only records Fridays where the screener actually
ran, which (per `weinstein_strategy_macro.entry_transitions_if_active`) requires
`halted=false` at the entry step. Recorded entries near the cascades:

| Friday | Trend |
|---|---|
| 2025-02-28 | Bullish |
| 2025-03-07 | Neutral |
| 2025-04-04 | Neutral |
| 2025-04-11 | **Bearish** |
| 2025-05-02 | Neutral |
| 2025-05-16 | Neutral |

Missing Fridays (04-18, 04-25, 05-09, 05-23, 05-30) = days where halt was Halted at
screening time, so no `record_cascade_summary` was called.

Implied Bearish → non-Bearish transitions (each releases the halt once via
`_maybe_reset_halt`):

1. **2025-05-02** Bearish (from 04-11) → Neutral. Re-arms halt for cascade #2 (Monday 05-05).
2. **2025-05-16** Bearish → Neutral. The 05-09 trend is NOT in the log, but for halt
   to have been reset by 05-16 (so screening could run and log the entry) macro must
   have re-flipped Bearish on 05-09 and back to Neutral on 05-16. Re-arms halt for
   cascade #3 (Monday 05-19).

So the gate mechanically permits 3 cascades: the initial fire (04-17, during the
Bearish week itself) + 2 re-fires after Bearish→Neutral transitions. **The
transition-only reset gate is doing exactly what PR #1052 specified.**

## 2. Equity-curve sanity check — Portfolio_floor breach is impossible at real values

`force_liquidation.ml:239` fires when `portfolio_value < peak * 0.4`. Default
floor fraction = 0.4 (`force_liquidation.ml:22`).

- All-time peak (`equity_curve.csv`): **$4,555,330 on 2021-06-01**. 0.4 × peak = $1,822,132.
- Recent peak before cascades (~2025-03-03): $3,707,112. 0.4 × peak = $1,482,845.
- Portfolio_value at cascade dates: **$3,614,536 (04-17), $3,618,726 (05-05),
  $3,629,101 (05-19)** — i.e. ~78-79% of all-time peak, ~97-98% of recent peak.
- `actual.sexp` reports `max_drawdown_pct = 21.35` over the entire 16y run.

**No date in the equity curve falls below 45% of running peak.** Yet
Portfolio_floor fired three times. Conclusion: `portfolio_value` passed into
`FL.check` differs from the equity_curve.csv value at the cascade tick.

Suspect mechanism: `Portfolio_view._holding_market_value`
(`portfolio_view.ml:19-25`) returns **0.0** when `get_price` returns None for a
holding. Across the bar boundary, holdings that lack a price-bar collapse the
mark-to-market sum to ~cash-only, which can fall below the floor when most NAV
is deployed in positions. This is the same class of bug as G9/G12 (memo in the
.mli on `force_liquidation_runner.mli:42-54`), reappearing in a new shape.

Adjacent equity-curve flatlines (04-18 → 05-02 frozen at $3,613,923.53; 05-06 →
05-16 frozen at $3,614,960.78) match the simulator NAV fallback bug pattern
(`memory/project_simulator_nav_fallback_bug.md`).

## 3. Position-ID continuity across cascades

All 13 Portfolio_floor positions are **distinct**, fresh entries (IDs 8188 →
8234, monotonic):

- 04-17 cascade: ED-8188, TAP-8201, VZ-8205 (entered 2025-03-08 / 03-15).
- 05-05 cascade: GT-8225, HRB-8224, SII-8226, TRV-8227 (all entered 2025-05-03,
  2 trading days before cascade).
- 05-19 cascade: CTAS-8230, EMC-8231, FAST-8232, GE-8233, GT-8234, NRG-8229
  (all entered 2025-05-17 — Saturday-dated, executed Monday 05-19).

Each cascade flushes the book, the screener immediately re-enters on the next
Friday (post-reset), and the new cohort gets force-liquidated near-instantly.
Same-symbol overlap (GT, TRV, SII reappearing) but distinct position_ids → not
a re-fire on surviving positions; the death-loop suppression is working.

## 4. Verdict

The PR #1052 halt-gate **is mechanically correct**: only one Portfolio_floor
re-fire happens per Bearish → (Bullish|Neutral) macro transition, and we see
exactly that ratio (1 initial + 2 re-fires = 3 cascades; 2 implied transitions
on 2025-05-02 and 2025-05-16 plus the initial 04-11 Bearish week).

**However the underlying Portfolio_floor signal is firing on a falsehood.** Real
equity ~78% of peak should never trip a 40% floor. Two contributing bugs (both
known, neither fully fixed):

1. **`Portfolio_view._holding_market_value` returns 0 on missing price** —
   suspected primary mechanism: newly-entered positions (entries dated 05-03 /
   05-17) likely lack a price-bar on the cascade tick, deflating
   `portfolio_value` to ~cash, which is below `0.4 * peak` when most NAV is
   deployed.
2. **Simulator NAV fallback** (`memory/project_simulator_nav_fallback_bug.md`,
   `simulator.ml:213-214`) — equity curve flatlines between cascades, consistent
   with stale `current_cash` substitution.

The death loop (307 → 13 events) is *suppressed* but the falsity that drives
the loop is *not removed.* Three cascades in 8 weeks on a portfolio at -22%
drawdown is still wrong. Recommended follow-ups:

- F1. Make `_holding_market_value` either propagate a stale `Some bar` from the
  last-known price (forward-fill at the Portfolio_view layer) or surface an
  explicit "stale" flag so `FL.check` can skip the floor evaluation when
  mark-to-market is not trustable.
- F2. Land the simulator NAV-fallback fix (open PR #1019 per memory) so
  equity_curve.csv stops flatlining and ground-truth divergence is visible.
- F3. Optional belt-and-braces: gate Portfolio_floor on a *rolling* portfolio
  high-watermark (e.g. trailing 12 months) rather than all-time peak, so that
  one 2021 high doesn't dominate the floor through 2025.

## File references

- `dev/backtest/scenarios-2026-05-12-194906/sp500-2010-2026-longshort-historical/force_liquidations.sexp:6-57`
- `dev/backtest/scenarios-2026-05-12-194906/sp500-2010-2026-longshort-historical/macro_trend.sexp:380-388`
- `dev/backtest/scenarios-2026-05-12-194906/sp500-2010-2026-longshort-historical/equity_curve.csv:3948-4012`
- `dev/backtest/scenarios-2026-05-12-194906/sp500-2010-2026-longshort-historical/actual.sexp:6` (force_liquidations_count 14, max_drawdown_pct 21.35)
- `trading/trading/weinstein/portfolio_risk/lib/force_liquidation.ml:236-262` (halt gate)
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml:53-58` (`_maybe_reset_halt`)
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_macro.ml:70-81` (`entry_transitions_if_active` — halt gates screener which gates macro_trend logging)
- `trading/trading/strategy/lib/portfolio_view.ml:19-25` (suspected primary bug: 0.0 default on missing price)
- `trading/trading/backtest/lib/macro_trend_writer.ml:8-15` (macro_trend.sexp built from cascade_summary list — explains the missing Fridays)
