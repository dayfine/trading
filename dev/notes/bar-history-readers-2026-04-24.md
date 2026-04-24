# Audit: Bar_history readers — binding lookback window (2026-04-24)

PR 2 of `dev/plans/bar-history-trim-2026-04-24.md`. Read every
production caller of `Bar_history.daily_bars_for` /
`weekly_bars_for` (and any direct `Hashtbl.find` on the underlying
`t`), record their effective lookback, and confirm 365 days is a
safe binding window for the trim default.

## Production callers

Searched: `grep -rn "Bar_history\." trading/trading/weinstein
trading/trading/backtest --include="*.ml"` and inspected.

| # | Site | API | Lookback | Resolved value |
|---|------|-----|----------|----------------|
| 1 | `weinstein/strategy/lib/macro_inputs.ml:28` (`build_global_index_bars`) | `weekly_bars_for ~n:lookback_bars` | `lookback_bars` (weekly) | `config.lookback_bars` = 52 weeks → **364 days** |
| 2 | `weinstein/strategy/lib/macro_inputs.ml:39` (`_sector_context_for`) | `weekly_bars_for ~n:lookback_bars` | same | **364 days** |
| 3 | `weinstein/strategy/lib/stops_runner.ml:11` (`_compute_ma`) | `weekly_bars_for ~n:lookback_bars` | same | **364 days** |
| 4 | `weinstein/strategy/lib/weinstein_strategy.ml:100` (entry transition) | `daily_bars_for` (no `~n`) | `Weinstein_stops.compute_initial_stop_with_floor`'s `bars` arg | needs trace through to `Support_floor` |
| 5 | `weinstein/strategy/lib/weinstein_strategy.ml:190` (per-position MA) | `weekly_bars_for ~n:config.lookback_bars` | weekly | **364 days** |
| 6 | `weinstein/strategy/lib/weinstein_strategy.ml:284` (primary index check) | `weekly_bars_for ~n:config.lookback_bars` | weekly | **364 days** |

Direct `Hashtbl.find` / map iteration on `Bar_history.t`: none in
production code (only the module's own `accumulate` / `seed` /
`weekly_bars_for` / `daily_bars_for` touch the table).

## Trace site #4 — the only daily_bars_for production caller

`weinstein_strategy.ml:100` passes the full daily-bar list to
`Weinstein_stops.compute_initial_stop_with_floor ~bars:daily_bars`.

Inside `weinstein_stops.ml:80`, that call invokes
`Support_floor.find_recent_low ~bars
~lookback_bars:config.support_floor_lookback_bars`.

`config.support_floor_lookback_bars` default is `90` (per
`stop_types.ml:49` — `default_config` initializer).

`Support_floor._window` (in `support_floor.ml:16`) computes
`_eligible bars ~as_of` then `_trim_to_lookback eligible 90`.
`_eligible` filters to bars whose date is `<= as_of`, so the window
is the most recent 90 *eligible* daily bars before (and including)
`as_of`.

In a calendar with weekday-only US trading and standard holidays,
90 trading days ≈ **126 calendar days** (90 × 7/5). Bigger if a
symbol has missing data, but Support_floor would just have fewer
eligible bars to trim, not reach further back.

**Site #4 effective lookback: ≤ ~130 calendar days.** Comfortably
under 365.

## Binding window — confirmed: 365 days

Every reader caps at either 52 weeks (= 364 days) or ~130 calendar
days. **365 days is a safe trim window:** no production reader will
ever observe a bar dropped by `Bar_history.trim_before t ~as_of
~max_lookback_days:365`.

Margin: the worst case is `max_lookback_days = 364` would still be
safe (sites 1/2/3/5/6 take exactly 52 weekly bars; weekly
aggregation needs 364 daily bars worth of data to produce 52 weekly
bars including the current partial week, per
`Time_period.Conversion.daily_to_weekly` with
`include_partial_week:true`). 365 buys 1 day of safety in case of
calendar / DST edge cases without measurable memory cost.

**Recommended default for PR 5 of the trim plan:**
`bar_history_max_lookback_days = Some 365`.

## Test coverage we already have

`test_bar_history.ml` (post-#525) has 6 tests for `trim_before`:
empty buffer, trim-then-accumulate, idempotency, future-as_of,
zero-lookback, negative-lookback raises. The integration tests in
PR 3 will need to add at least one parity assertion: full
6-year backtest with `max_lookback_days = Some 365` produces
bit-identical trade list and PV vs `None`.

## What to update in the trim plan

`dev/plans/bar-history-trim-2026-04-24.md` PR 2 section can be
marked done with a pointer to this file. PR 3 can proceed with
`Some 365` as the integration test's chosen lookback.

## Out of scope

- Reader callers in tests: 21 sites in `test_bar_history.ml`,
  `test_weinstein_strategy.ml`, `test_stops_runner.ml`,
  `test_macro_inputs.ml`. Tests construct synthetic histories of
  ~10–100 bars; no test exceeds 365 days. Trim default safe for
  tests too.
- Tier-aware paths: `tiered_runner.ml`, `tiered_strategy_wrapper.ml`,
  `bar_loader.ml`. These call `Bar_history.seed`, never read via
  `daily_bars_for` / `weekly_bars_for`. So Tiered code is invariant
  under the trim — only the seed path matters, and `seed` already
  filters by date.

## Decision deferred to PR 3 author

Where to call `trim_before` (per the plan's decision item #2):
- Per-day in `Weinstein_strategy.on_market_close` — uniform across
  Legacy and Tiered. **Recommended.**
- Per-week (Friday only) — amortizes work but keeps a 7-day buffer
  of stale bars.
- Per-promote (Tiered only, on Full promote) — only Tiered benefits.

Strong recommendation: per-day in `on_market_close`. Both Legacy
and Tiered benefit. Cost is one Hashtbl iteration per day per
strategy invocation — trivial.
