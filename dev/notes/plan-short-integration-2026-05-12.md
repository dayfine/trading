# Plan — Proper short integration / long-short strategy — 2026-05-12

Forward-looking note. Reframes the question after the short-side survey:
the short-side primitives are **already merged** (G1–G9 closed 2026-04-30).
The open question is **how to exercise them broadly + how to set the
default config**.

## What's already done

Per the in-conversation survey (2026-05-12) and `dev/status/short-side-strategy.md`:

| Primitive | Status |
|---|---|
| Stage 4 breakdown detection | MERGED (`Screener._is_breakdown_candidate`) |
| Short candidate scoring + RS gate | MERGED (`Screener._short_candidate`, `_support_signal`, `_rs_short_signal`) |
| Short initial stop (resistance-ceiling) | MERGED (`Weinstein_stops.compute_initial_stop_with_floor ~side:Short`) |
| Short stop trailing + tightening | MERGED (G1, PR #689 — direction + sign fixes) |
| Short position sizing | MERGED (G7, PR #702 — separate `max_position_pct_short = 0.20`) |
| Short notional cap | MERGED (G15 step 2, PR #706 — `max_short_notional_fraction = 0.30`) |
| Short force-liquidation | MERGED (G4 / G8 / G9 — signed portfolio value) |
| Backtest regression gate | sp500-2019-2023 (5y), 4 short trades, 0 force-liqs |

`enable_short_side` defaults to `true` in code. **But all production
goldens override it to `false`** (`goldens-sp500-historical/sp500-2010-2026.sexp`
etc.).

## What's NOT done

### Gap 1 — Goldens don't exercise shorts

Every long-window production scenario sets `enable_short_side = false`.
The strategy works, but its long-short combined behavior over 10y / 15y
windows is **untested at a baseline scale**. The 5y sp500-2019-2023
regression gate exists but covers only one bear-spike window (2019).

### Gap 2 — Default config disagreement

- Code default: `enable_short_side = true`.
- Goldens default: `enable_short_side = false` override.
- This split means a fresh user spinning up a backtest gets shorts on; a
  reproduced golden gets shorts off.

### Gap 3 — Short-side risk-control tuning (G15)

`dev/status/short-side-strategy.md` flags G15 as open: "tighter short stops
+ portfolio floor based on true peak observations." Short stops currently
use the same `min_correction_pct = 0.08` as longs. Empirical question
whether shorts benefit from a different value (e.g. tighter, since
short P&L is bounded above at 100% while losses are unbounded).

### Gap 4 — No long-short combined goldens

The strategy *supports* simultaneous long + short positions, but no
goldens exercise both sides actively. Don't know how the strategy
behaves when:
- 5 longs + 3 shorts open simultaneously (interleaved cash claims).
- A long stops out same Friday a new short enters.
- Macro flips Bullish → Bearish mid-Friday-walk (which side wins the cash?).

## Recommended sequence

### Phase A — Cut a long-short golden

1. Pick the existing `sp500-2010-2026` scenario (16y).
2. Clone it as `sp500-2010-2026-longshort.sexp` with `enable_short_side =
   true` and same universe / portfolio config.
3. Run + pin baselines. Flag it as `long-short` perf-tier (3 or 4).
4. Acceptance: positive Sharpe AND clean force-liq audit. Expected
   outcome (per 5y data): shorts hurt total return but reduce drawdown
   on the 2020 + 2022 down legs.

Cost: 1 session. Unlocks Phase B.

### Phase B — Decide default config

Three options:

1. **Code default true; goldens explicit.** Keep the current code default
   `enable_short_side = true`; goldens that want long-only keep their
   override. Less surprising for a fresh user who reads the strategy
   docstring (which mentions both sides).
2. **Code default false; goldens explicit.** Flip to `enable_short_side =
   false` in code; goldens that want shorts add an override. Conservative
   default — current observed behavior.
3. **Document the gap.** Leave both as-is but add an explicit note in the
   weinstein-trading-system-v2 design doc explaining the
   default-vs-goldens split.

**Recommendation:** Option 2. Conservative default. New users see the
configurable knob and opt-in. Sweepers who want shorts add one line.

Cost: trivial (1-line + doc). Blocked on Phase A landing first so we have
data on what the "shorts on" default would look like.

### Phase C — G15 risk-control tuning sweep

Once Phase A is pinned, sweep:
- `stops_config.min_correction_pct` × `{0.04, 0.06, 0.08, 0.10, 0.12}` for
  shorts only (need a new config field — `min_correction_pct_short` —
  unless we want to apply the same value to longs).
- `portfolio_config.max_short_notional_fraction` × `{0.15, 0.20, 0.30, 0.40}`.
- `portfolio_config.max_position_pct_short` × `{0.10, 0.15, 0.20, 0.25}`.

3-dim × 5×4×4 = 80-cell sweep. ETA ~1 hour on the new `--parallel 3` grid
runner against the 5y sp500-2019-2023 regression scenario.

### Phase D — Long-short combined edge cases

Pin behavior tests for the 4 unknowns in Gap 4:
- Same-Friday long-exit + short-entry (cash accounting).
- Macro flip mid-walk.
- Force-liquidation under mixed exposure (signed portfolio value).
- 50/50 long/short max-exposure scenario.

Cost: 1 session of test-writing, no production code changes expected.

## Cross-references

- Short-side strategy track: `dev/status/short-side-strategy.md`
- 5y regression gate: `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2019-2023.sexp`
- G15 issue (open): see `dev/status/short-side-strategy.md` §"Open follow-ups"
- Force-liquidation findings: `dev/notes/force-liq-cascade-findings-2026-05-01.md`
- Memory note: "Reprioritize short-side follow-ups after optimization lands" — `memory/project_short_side_reprioritize.md`
