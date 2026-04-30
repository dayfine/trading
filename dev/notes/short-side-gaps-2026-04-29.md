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

**DONE — see PR `fix/trailing-phantom-cycle`** (2026-04-30): added a
`correction_observed_since_reset : bool` field to the `Trailing` state
constructor. The cycle gate in `_completed_cycle_stop` now requires
`correction_count = 0 || correction_observed_since_reset`: the first
cycle is allowed to fire on the entry-bar-extreme seed (preserves the
long-side `stage2_trailing_stop_raised_phase_a` contract), and
subsequent cycles after a `_raised_trailing` reset require a real
counter-move bar — `bar.low ≤ last_correction_extreme` for longs or
`bar.high ≥ last_correction_extreme` for shorts — to refresh the
anchor before the cycle math can re-fire. Pre-fix on a 10-bar
monotonic short decline the stop drops from $103.125 (entry stop) to
$90.125 (below entry close $99) via two phantom cycles; post-fix the
stop drops to $101.125 on the seed-anchored cycle 1 and holds there
across the remaining decline (count remains 1, second phantom is
rejected). New regression scenarios in
`trading/trading/weinstein/stops/test/regression_test.ml`:
`short_monotonic_decline_no_phantom_cycle` and the symmetric
`long_monotonic_advance_no_phantom_cycle`. Long-side
`stage2_trailing_stop_raised_phase_a` and `_phase_b` continue to pass
unchanged. `stage3_tightening` updated to set
`correction_observed_since_reset = true` (it constructs an initial
state that explicitly models a real prior pullback). Round-number
nudge and `_advance_tracking` math are unchanged.

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

**DONE — see PR `feat/portfolio-cash-floor-shorts`** (2026-04-29):
soft semantics adopted. New
`Portfolio.unrealized_pnl_per_position : (symbol * float) list`
field + `Portfolio.mark_to_market` API; `_check_sufficient_cash`
extended to apply on both Buy and Sell sides using effective cash =
`current_cash + cash_change + sum(min(0, unrealized_pnl_per_position))`.
12 new portfolio unit tests cover short entry/cover under sufficient
cash, rejection when unrealized drag exceeds available cash, cumulative
floor across a sequence of shorts, mark-to-market drop semantics, and
asymmetric clamping (positive unrealized PnL never inflates floor).
Strict broker-margin variant deliberately deferred.

G4 (force-liquidation policy) ships as a sibling PR after this lands
and will wire into the new `mark_to_market` + accumulator surface.

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

**DONE — see PR `feat/force-liquidation`** (2026-04-29): defaults
50% per-position unrealized-loss threshold + 40% portfolio-of-peak
floor (configurable via `Portfolio_risk.config.force_liquidation`).
New module `Portfolio_risk.Force_liquidation` (pure check + mutable
`Peak_tracker`) plus `Weinstein_strategy.Force_liquidation_runner`
wiring TriggerExit transitions and routing events through a new
`Audit_recorder.record_force_liquidation` callback. Backtest-side:
new `Force_liquidation_log.t` collector, `force_liquidations.sexp`
artefact, and `trades.csv` exit-trigger column overrides
(`force_liquidation_position` | `force_liquidation_portfolio`). Per-
scenario count surfaces in the release-perf report's trading-metrics
table with a non-zero red-flag glyph. Halt state in `Peak_tracker`
suppresses new entries until macro flips off Bearish.

**REWORK DONE (2026-04-29, second commit on PR #695)**: applied
qc-behavioral findings B1–B3.
- **B1 (load-bearing)**: halt-resume bug fixed by splitting
  `_run_screen` into `_run_macro_only` + `_run_screen_after_macro` and
  running the macro pass + `_maybe_reset_halt` on every Friday
  including halted Fridays. Pre-fix the halt latched permanently
  because `prior_macro` never refreshed after the floor fired.
- **B2**: end-to-end `trades.csv` exit-trigger pinning via new
  `test_result_writer.ml` (3 tests covering both labels + non-match).
- **B3**: defensive guards pinned — zero cost-basis, zero quantity,
  non-Holding position, missing price, double-exit avoidance (5 new
  tests across `test_force_liquidation.ml` and
  `test_force_liquidation_runner.ml`).
- Test seam: new `Weinstein_strategy.Internal_for_test` exposing
  `on_market_close` / `maybe_reset_halt` / `positions_minus_exited`
  for direct strategy-level testing without going through `make`'s
  closure.

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

**2026-04-30 update**: rerun attempted on 2026-04-30 after G1-G5 landed
(#689-#695). Surfaced new gap **G7 — position sizing for shorts**.
Details in `dev/notes/sp500-shortside-rerun-blocked-g7-2026-04-30.md`.
Force-liquidation fired 910× because shorts were sized at >100 % of
portfolio (ABBV 2019-02-01: $1.238M position vs $1M portfolio). G3 cash
floor passed the entry; sizing helper or cash-check has the bug.

**2026-04-30 PM update**: second rerun attempted after G7 (#702) and G8
(#705) landed. Force-liquidation count dropped from 910 → 928 (only
marginal change), avg_holding_days remained at 3.46 (vs. expected
~70+). Surfaced new gap **G9 — `Force_liquidation_runner._portfolio_value`
has the same shorts-sign bug as pre-G8 `Portfolio_view._holding_market_value`**
(G8 only patched one of two sites). Details in
`dev/notes/sp500-shortside-rerun-blocked-g9-2026-04-30-pm.md`.
Profitable shorts being force-liquidated on 2019-02-14 (ABBV +$21,596,
CVS +$21,635, etc.) — `Portfolio_floor` fires because the buggy
portfolio_value tracking inflates the peak then "drops" below 40 % of
that inflated peak.

Once G1 + G2 + G3 + G4 + G7 + G8 + **G9** close, the sp500 scenario's
`config_overrides` should be reverted (drop the override, defaulting
back to `enable_short_side = true`), the BASELINE_PENDING expected
ranges re-pinned to whatever the with-shorts run produces, and G5
added as the standing regression gate.

## G7 — Position sizing for shorts

See `dev/notes/sp500-shortside-rerun-blocked-g7-2026-04-30.md` for
full details. Summary:

- Symptom: shorts open with position_value > portfolio_value (ABBV
  $1.238M vs $1M portfolio). Cash floor (G3) does not reject.
- Likely fix surface: `Portfolio_risk.compute_position_size` or
  `Portfolio._check_sufficient_cash` Sell-entry branch.
- Owner: `feat-weinstein` (portfolio_risk + sizing scope).
- Pre-fix test: a $1M portfolio + $100/share short with default
  `max_short_exposure_pct` should size `target_quantity * entry_price
  ≤ max_short_exposure_pct * portfolio_value`. Currently fails.

**DONE — see PR `feat/g7-short-position-sizing`** (2026-04-30):
leaking surface was `Portfolio_risk.compute_position_size`. The risk-
budget formula `shares = floor(dollar_risk / |entry - stop|)` is
unbounded when `|entry - stop|` is small relative to `dollar_risk`.
The `max_long_exposure_pct` / `max_short_exposure_pct` config knobs
(default 0.90 / 0.30) existed but were only consumed by
`Portfolio_risk.check_limits`, which is **never called from the live
entry pipeline** (zero non-test callers).

Fix: added `~side` parameter to `compute_position_size`; final share
count is now `min(risk_based_shares, exposure_capped_shares)` where
`exposure_capped_shares = floor(portfolio_value * max_exposure_pct /
entry_price)`. Pre-fix the ABBV-shape test ($1M portfolio, $101.59
entry, $102.41 stop, side=Short) sized 12,195 shares ($1.238M); post-
fix sizes 2,953 shares ($300K = 30% cap × $1M). Symmetric long-side
cap also pinned (max 90%). Five new tests in
`test_portfolio_risk.ml`; existing 4 long-side tests updated for the
new required `~side` arg. Also absorbed the Long/Short entry-stop
swap that used to live in
`Entry_audit_capture._normalised_entry_stop_for_sizing` into
`compute_position_size` itself (now uses `Float.abs (entry - stop)` +
side-direction validation).

Re-enabling shorts on sp500-2019-2023 (the validation rerun) is **not
done in this PR** — left as the next step. The override stays in
place. G7 closing means `compute_position_size` no longer produces
oversized entries; whether that's *sufficient* to drop the force-
liquidation count to single digits (and produce a defensible short-
side baseline) is what the rerun will measure.

## G8 — `Portfolio_view.portfolio_value` ignores `pos.side`

Surfaced 2026-04-30 by qc-behavioral on PR #702 (G7 fix).

- Symptom: `Portfolio_view.portfolio_value` summed `quantity *.
  close_price` for every `Holding` regardless of `pos.side`. Since
  `Position.t.state.Holding.quantity` is unsigned and the long/short
  direction lives in `pos.side`, short positions inflated
  `portfolio_value` instead of subtracting from it.
- Impact: any consumer reading
  `Trading_strategy.Portfolio_view.portfolio_value` saw paper-rich
  portfolios on bear-side trades. Sizing / risk / metrics that key off
  this number all read inflated. Direct caller in the live entry path:
  `Weinstein_strategy._build_entry_inputs` (uses portfolio_value to
  compute target dollar exposure) — short candidates were sized as if
  the short already counted as an asset twice over.
- Leaking surface: `trading/trading/strategy/lib/portfolio_view.ml`,
  `_holding_market_value` (single function — the strategy-side mark-to-
  market path).
- Not affected: `trading/trading/portfolio/lib/calculations.ml`. That
  module's `market_value` / `unrealized_pnl` use the signed-quantity
  convention from `lots.quantity` (negative for shorts), so it already
  signs correctly. The bug was strictly the strategy-side
  `Portfolio_view`, which carries the `Position.t` shape (unsigned
  `quantity` + separate `side`).

**DONE — see PR `fix/g8-portfolio-view-shorts`** (2026-04-30):
`_holding_market_value` now matches on `pos.side` and contributes
`+quantity * close_price` for `Long` and `-quantity * close_price` for
`Short`. The fix is strategy-agnostic — works for any STRATEGY that
returns long+short positions, no Weinstein-specific logic. Three new
tests in `test_portfolio_view.ml` (short at profit, short at loss,
mixed long+short) plus the existing two long-side tests, all explicit
numeric assertions. No existing tests required updates: pre-fix the
weinstein-strategy / simulation suites passed because their fixtures
either used long-only positions or did not pin `portfolio_value` at a
specific number.

## G9 — `Force_liquidation_runner._portfolio_value` has the same shorts-sign bug

Surfaced 2026-04-30 PM on the post-G8 sp500 rerun. See
`dev/notes/sp500-shortside-rerun-blocked-g9-2026-04-30-pm.md` for full
details.

- Symptom: 928 `Portfolio_floor` force-liquidations on a $1M-starting
  portfolio that never legitimately dropped below $774K (per the
  equity_curve, which uses the correct
  `Trading_portfolio.Calculations.portfolio_value`). The first
  force-liquidation batch on 2019-02-14 includes ABBV short
  +$21,596 unrealized, CVS +$21,635, HWM +$30,412 — profitable
  shorts that should not trigger any floor.
- Root cause: `Force_liquidation_runner._portfolio_value`
  (`trading/trading/weinstein/strategy/lib/force_liquidation_runner.ml:33-41`)
  duplicates `Portfolio_view._holding_market_value`'s logic but
  uses the unsigned `Holding.quantity` directly. G8 (#705) fixed
  `Portfolio_view._holding_market_value` but did not patch this
  sibling copy.
- Effect: cash inflates with each short entry (proceeds credited).
  Buggy `_portfolio_value` adds positive position-values on top of
  inflated cash → tracked peak is roughly 2× the true peak. As shorts
  profit (price drops), `quantity * close_price` decreases → buggy
  portfolio_value drops below 40 % of inflated peak →
  `Portfolio_floor` fires on profitable shorts.
- Leaking surface: single function in
  `trading/trading/weinstein/strategy/lib/force_liquidation_runner.ml`.
  Mechanically identical to G8's fix shape — sign by `pos.side`. Or
  delegate to `Portfolio_view.portfolio_value` to remove the
  duplicate code path.
- Fix surface (post-investigation): one-line sign-by-side fix +
  regression test pinning the inflated-peak vs. corrected-peak shape.
  Should not exceed 100 LOC.
- Owner: `feat-weinstein` (force_liquidation_runner scope).
