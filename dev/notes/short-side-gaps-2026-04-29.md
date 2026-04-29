# Short-side gaps surfaced 2026-04-29

The sp500-2019-2023 baseline rerun on post-#680 main produced impossible
metrics — −144.5 % return, 245.8 % MaxDD, portfolio_value going negative
on multiple days through 2020-2021. Diagnostic agent (PR #681) ruled out
the broker-model split-day path (PRs #678 / #679 / #680 are correct fixes
for what they targeted). Root cause: the Weinstein strategy emits
~128 short entries during 2019's Bearish-macro window, those shorts ride
the 2020-2023 bull market accumulating unbounded losses, and several
short-side guard rails do not engage. Until the gaps below are closed,
sp500 (and any scenario that crosses a Bearish-macro window) runs with
`enable_short_side = false` — see commit landing this note for the
config-flag wire-in.

## Gaps

### G1 — Stops on shorts do not fire correctly

Audit evidence: `dev/backtest/scenarios-2026-04-29-172747/sp500-2019-2023/trade_audit.sexp`
records ALB short with stop $103.58 exiting at $77.49 on 2019-01-29 when
ALB price was at $76. For a short, the stop should sit ABOVE entry and
fire when price moves UP through it; price at $76 against stop $103 is
profitable territory and should NOT trigger an exit. Strong smell of
`Stops_runner.update` evaluating the comparison with the long-side
sense.

**Authority**: `docs/design/weinstein-book-reference.md` §Stop-Loss
Rules — short stops are placed above entry; trigger condition is
`weekly close >= stop_level`.

**Fix surface**: `trading/trading/weinstein/portfolio_risk/lib/stops.ml`
(or wherever `Stops_runner.update` lives). Audit the
`check_stop_hit` direction logic for `Side.Short` cases. Add a
regression test in `trading/trading/weinstein/portfolio_risk/test/`
that pins both directions: short with price below stop → no trigger;
short with price above stop → trigger.

**Diagnosed (PR `fix/g1-short-stop-diagnosis`, DRAFT)**: the original
hypothesis ("`Stops_runner.update` evaluating with long-side sense")
was wrong — PR #689 audit harness Tests A + B already pin the
unit-level `Weinstein_stops.check_stop_hit` predicate as
direction-correct. Two distinct bugs in `Stops_runner` produce the
audit anomaly:

1. **Stage hardcode** in `Stops_runner._handle_stop`. When invoking
   `Weinstein_stops.update`, the runner unconditionally passes
   `~stage:(Stage2 { weeks_advancing = 1; late = false })` — regardless
   of position side. For shorts in warmup (the `weekly.n < ma_period`
   branch where `ma_direction = Flat`),
   `Weinstein_stops._should_tighten_short` matches `Stage1 | Stage2 ->
   tighten` and fires `Entered_tightening` on the first Initial-state
   tick. The candidate computed from the bar high (e.g. $98 + 1 % buf
   ≈ $99 for an entry-bar high of $98) is "better" than the entry
   stop $103.58 in short-direction logic, so the stop drops to ~$99
   on bar 1 — already BELOW entry. Any subsequent small counter-bounce
   above the eroded stop fires a spurious exit at a profitable price
   (the ALB pathology shape).

2. **`actual_price = bar.low_price` hardcode** in
   `Stops_runner._make_exit_transition`. For longs, `bar.low_price` is
   the worst-case fill on a stop trigger (the bar's low crosses DOWN
   through the stop). For SHORTS, the trigger fires on `bar.high >=
   stop_level` and the worst-case cover fill is at `bar.high_price`,
   not `bar.low_price`. With the legacy hardcode, the audit log
   records ALB exit `actual_price = $77.49` when the actual trigger
   occurred at the bar's high (≥ $103.58). This makes the audit entry
   read as "stop fired against profitable territory" even when the
   trigger itself was correct.

**Fix**: `Stops_runner._compute_ma` now also returns the classified
stage (or a position-favourable warmup default: `Stage2 + Rising` for
longs, `Stage4 + Declining` for shorts — both no-tighten by
`_should_tighten_*`'s logic). `_make_exit_transition` selects
`actual_price` by side: `bar.low_price` for longs, `bar.high_price`
for shorts.

**Reproducer tests**: two new tests in
`trading/trading/weinstein/strategy/test/test_stops_runner.ml` —
`test_g1_short_no_exit_on_counter_bounce` (pins #1: short with
$103.58 stop emits zero exits across pullback + small counter-bounce
below entry) and `test_g1_short_exit_records_high_not_low` (pins #2:
on a violent down-day where bar high crosses the short stop, the
recorded `actual_price` and `exit_price` must be ≥ stop_level, not
bar.low). Both fail on current main, pass post-fix.

**Side-effect on long-side test**:
`test_weinstein_strategy.test_bar_accumulation_multiple_days` was
pinning the same warmup-tightening pathology for longs (Day 2
expected 1 transition driven by spurious tightening). Updated to
expect 0 transitions across all 3 days — the position-favourable
warmup default applies symmetrically to both sides.

**Out-of-scope follow-up**: there is a deeper Trailing-state
phantom-cycle bug in `Weinstein_stops._completed_cycle_stop`. For
monotonically declining shorts (no actual counter-rally), the seeded
`last_correction_extreme = bar.high` from `_to_trailing` paired with
an advancing `last_trend_extreme` later phantom-fires the cycle
without a real counter-move. This pulls the short stop further DOWN
through entry over multiple bars. Fixing it cleanly requires a
state-machine change (track temporal ordering of correction-vs-trend
extremes — naive seeding-reset breaks the long-side `regression_test`
at `stage2_trailing_stop_raised_phase_a` which deliberately seeds
the entry-bar low as the cycle-1 correction anchor). The minimal G1
fix above closes the runner-side hardcodes and lets the trailing
logic operate on correct stage inputs. Re-evaluate after the
sp500-baseline rerun whether the runner-side fix alone is sufficient
or whether the trailing-state phantom needs follow-up work.

### G2 — `Metrics.extract_round_trips` is blind to shorts

Currently pairs Buy → Sell only. Sell → Buy short round-trips are
silently dropped. Consequence: `trades.csv` shows zero AAPL trades on
sp500-2019-2023 even though 128 short entries fired (visible only in
`trade_audit.sexp`). Reviewers cannot eyeball the short-side trade
log.

**Fix surface**: `trading/trading/simulation/lib/metrics.ml` —
`_is_buy_sell_pair` and any callers. Add Sell → Buy pairing for
shorts. Be careful with the entry-price vs cost-basis semantics:
realized P&L on a short = entry_price − cover_price (mirror of long).

### G3 — Cash floor only fires on Buy

`Portfolio._calculate_cash_change` and `_check_sufficient_cash` only
trigger insufficient-cash errors on Buy orders. Short entries (Sell)
never hit a cash floor; short losses (Buy-to-cover) are evaluated
against the floor only on cover, not on accumulated unrealized loss.
Result: a short can ride into unbounded paper loss without any
guardrail forcing a close.

**Fix surface**: `trading/trading/portfolio/lib/portfolio.ml`. Decide
between two semantics:

- **Strict**: shorts require pre-locked collateral cash equal to
  some multiple of the entry value, decremented at Sell entry,
  refunded on cover. Mirrors broker margin requirements.
- **Soft**: portfolio carries an unrealized-loss accumulator per
  position; `_check_sufficient_cash` (or a new helper) considers
  `current_cash + sum(min(0, unrealized_pnl_per_position))` as the
  effective floor.

Either approach interacts with G4 below.

### G4 — No force-liquidation / margin-call mechanism

User suggestion (2026-04-29): defense in depth beyond stops. When a
position's unrealized loss exceeds a configured threshold (or when
portfolio_value drops below a configured floor), force-close the
position regardless of stop state. Crucially: the event should be
**logged + emitted as a signal**, not silently swallowed — every
forced liquidation is evidence that the strategy's primary stop
machinery failed to protect the trade.

**Proposed shape**:

- Add a `Force_liquidation` config block to
  `Portfolio_risk.config` with two thresholds: per-position
  `max_unrealized_loss_fraction` (e.g. 0.5 means force-close if a
  position's unrealized loss exceeds 50 % of original cost basis)
  and portfolio-level `min_portfolio_value_fraction` (e.g. 0.4
  means halt all entries + force-close all positions if
  portfolio_value drops below 40 % of initial cash).
- Emit a `ForceLiquidation` audit record per fired event with
  `{symbol, entry_price, current_price, unrealized_pnl_pct,
   stop_state, reason}`. These records must surface in
  `trades.csv` (with a distinct `exit_trigger`) AND in a new
  `force_liquidations.sexp` artefact alongside `trade_audit.sexp`.
- Wire counts into the per-scenario summary so the release report
  highlights "N force-liquidations on this run" — a non-zero count
  is a red flag the strategy's primary risk machinery isn't
  doing its job.

**Fix surface**: new module
`trading/trading/weinstein/portfolio_risk/lib/force_liquidation.{ml,mli}`
\+ wire-in at `Weinstein_strategy._on_market_close` after
`Stops_runner.update`. Audit-record schema extension under
`trading/trading/backtest/lib/trade_audit.{ml,mli}`. Tests at
`trading/trading/weinstein/portfolio_risk/test/`.

### G5 — Audit harness lacks a Weinstein-strategy-backed scenario

`test_split_day_audit.ml` (now 14 scenarios after PR #681) uses
`Make_scheduled` — a synthetic strategy that emits hand-coded actions.
The real Weinstein strategy was never exercised by the harness, so
gaps G1–G4 stayed invisible until the full sp500 run.

**Fix surface**: extend the audit harness with a scenario that wires
`Weinstein_strategy.make` into a `Make_scheduled`-style fixture
(small synthetic universe + bear-window bars). Pin: short-side stop
fires correctly under simulated upside breach; force-liquidation
fires under simulated unbounded paper loss; trades.csv contains the
short round-trip.

This becomes valuable AFTER G1–G4 are closed — it's the regression
gate for the fixes.

## Mitigation in flight

Commit landing this note flips `enable_short_side = false` in
`goldens-sp500/sp500-2019-2023.sexp` via
`(config_overrides (((enable_short_side false))))`. Existing scenarios
that consumed the prior config sexp continue to parse via
`[@sexp.default true]` on the new field. The flag default is `true`
(behavior-preserving); only the sp500 scenario opts out for now.

## Ownership

- **G1** (short stops): `feat-weinstein` (Weinstein_stops + Stops_runner
  scope).
- **G2** (metrics visibility): `feat-backtest` (simulation/lib/metrics).
- **G3** + **G4** (cash floor + force liquidation): cross-cutting —
  start with `feat-weinstein` (portfolio_risk decides the policy) but
  the cash mechanics live in `Trading_portfolio` (core, not
  strategy-specific). Likely needs a small core-module extension
  flagged via qc-structural A1 for human approval.
- **G5** (harness extension): `feat-backtest` (simulation/test).

## Re-enabling shorts

Once G1 + G2 + G3 + G4 close, the sp500 scenario's
`config_overrides` should be reverted (drop the override, defaulting
back to `enable_short_side = true`), the BASELINE_PENDING expected
ranges re-pinned to whatever the with-shorts run produces, and G5
added as the standing regression gate.
