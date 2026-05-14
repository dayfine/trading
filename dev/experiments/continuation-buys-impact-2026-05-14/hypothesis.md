# Continuation-buys impact — 5y sp500-2019-2023 (2026-05-14)

## Setup

Cell E baseline overlay (max_position_pct_long=0.14, max_long_exposure_pct=0.70,
min_cash_pct=0.30, stage3 force-exit h=1, laggard rotation h=2) on the 5y
sp500-2019-2023 universe (500 symbols). Two cells:

1. `baseline` — `enable_continuation_buys = false` (current default).
2. `continuation-on` — `enable_continuation_buys = true`, using the shipping
   `Continuation.default_config` (ma_slope_min=0.01, pullback_band=[0.95,1.05],
   pullback_lookback_weeks=8, consolidation_range_pct=0.10, consolidation_weeks=4).

## Authority

- PR #1078 — Interpretation B implementation, default-off.
- PR #1074 — design plan, `dev/plans/continuation-buys-2026-05-13.md`.
- Issue #889 — capital-recycling blind spot.
- `docs/design/weinstein-book-reference.md` §4.6 "Continuation Buys (Ch. 3)".

## Hypothesis

Continuation buys admit late-Stage-2 symbols (weeks_advancing > 4) that the
cascade currently rejects. The expected directional effect on 5y Cell E
(constrained capital, 0.14 sizing, 0.70 cap, 0.30 min-cash):

- **Trade count up.** New entry surface should add 5-30% to `total_trades` —
  enough to confirm wiring (sanity check), bounded by the existing 0.70 cap.
- **Return change ambiguous.** Late-Stage-2 entries are inherently riskier
  (trend more mature, less room to run); per-trade edge could compress. Net
  return delta could be slightly positive or slightly negative.
- **MaxDD / Sharpe likely flat or slightly worse.** More breakout entries
  in a volatile 2020 / 2022 regime would tend to widen drawdown unless the
  detector's MA-slope and consolidation gates suppress the worst late-Stage-2
  failures (which is what the book's continuation pattern was designed for).

## Falsifiability

- **Zero trade-count delta** would mean the continuation arm never fired —
  wiring bug or detector too strict at defaults. Sanity-fail.
- **Trade count up >50%** would indicate the cascade is now over-admitting;
  warrants a parameter-tuning follow-up before considering default-on.

## Decision criteria

- **Promote default-on** iff: return ≥ baseline, MaxDD within +1pp, Sharpe
  within −0.05, trade count delta in [+5%, +30%].
- **Keep default-off** iff: return drops ≥ 3pp or MaxDD widens ≥ 2pp.
- **Recommend tuning follow-up** for anything in between, with specific
  parameter suggestions (likely `ma_slope_min` tighter, or
  `consolidation_range_pct` tighter).
