# Force-liquidation cascade root-cause findings — 2026-05-01

Investigation triggered by `dev/notes/sp500-baseline-divergence-2026-04-30-pm.md`
(820 Day-1 force-liqs on profitable shorts in `sp500-2019-2023`, post-PR
#711 baseline). Categorized the cascade by mechanism and structurally
fixed the two phantom-peak pathways. The remaining 5 events trace to a
separate split-adjustment bug, filed as G14.

## Cascade timeline

| State                   | Force-liqs | Of which `Portfolio_floor` | Trades | sp500 return | sp500 MaxDD |
|-------------------------|----------:|---------------------------:|-------:|-------------:|------------:|
| Pre-G12 baseline        |       820 |                        820 |   1410 |       +39.3% |        8.7% |
| Post-G12 (#725)         |       449 |                        441 |    527 |       +46.6% |       28.7% |
| Post-G13 (#726)         |         5 |                          0 |    192 |       -66.7% |      117.5% |
| Pinned baseline         |         0 |                          0 |     32 |        -0.01 |        5.8% |

## G12 — `(positions, cash)` snapshot consistency at FL.update call site

**Mechanism.** `Weinstein_strategy._on_market_close` previously called
`Force_liquidation_runner.update` with `live_positions` (positions minus
the ones already stop-exited this tick) but with the unfiltered
`portfolio.cash` (buy-back debit not yet posted). When a short S1
stopped out, `Portfolio_view.portfolio_value` saw consistent positions
but stale cash:

- Pre-tick true pv: `cash + sum_full(-current * qty)`
- Buggy mid-tick pv: `cash + sum_full\{S1}(-current * qty) = pv_pre +
  current_S1 * qty_S1`

The mid-tick value got passed to `Peak_tracker.observe`, permanently
inflating peak by exactly the absolute mtm contribution of the stopped
short. On subsequent ticks pv returned to truth but peak stayed
elevated → cascade.

**Fix (#725).** Pass FULL pre-tick positions and pre-tick cash. Move
double-exit avoidance to post-filtering the returned transitions (drop
those whose `position_id` appears in the stop-exit set) instead of
hiding positions from the runner.

**Test.** `test_inconsistent_positions_cash_phantom_spikes_peak` in
`trading/weinstein/strategy/test/test_force_liquidation_runner.ml`
pins the math at the runner boundary by calling `update` twice with the
same `pre_tick_cash` and a fresh `peak_tracker` each time:

- Fixed combo: positions=full, cash=pre-tick → peak = true pv
- Buggy combo: positions=full \ {S1}, cash=pre-tick → peak inflated by
  `current_price_S1 * quantity_S1`

## G13 — non-trading-day short-circuit

**Mechanism.** The simulator iterates calendar days (Mon-Fri including
holidays); `_on_market_close` is invoked on days that have no bar in
`Bar_panels`. Pre-fix: when `get_price config.indices.primary` returned
None, `current_date` fell back to `Date.today` and the full pipeline
ran with phantom data. Critically, `Force_liquidation_runner.update`
ran with `cash` containing accumulated short proceeds but
`_holding_market_value` returning `0.0` for every position (no
`get_price` this tick) → `pv = cash` (well above true mtm-aware pv) →
`Peak_tracker.observe` phantom-spiked peak by every dollar of
accumulated short proceeds.

Empirically: peak got bumped ~$770K every weekend a new short opened,
eventually pinned at $2.74M. Floor at 0.4×peak = $1.096M; real-day pv
≈ $1M; cascade fired every Monday (449 events).

**Fix (#726).** Short-circuit at the top of `_on_market_close`: if
`get_price config.indices.primary` returns None, return
`Ok { transitions = [] }` immediately. Strategy doesn't run on
non-trading days.

**Test.** `test_no_primary_index_bar_short_circuits` in
`test_force_liquidation_strategy.ml`. Drives
`Internal_for_test.on_market_close` with `Bar_reader.empty ()` and a
portfolio holding $1.5M cash. Asserts: returned transitions empty,
`peak_tracker.peak = 0.0` (pre-fix would equal cash), halt state
stays Active.

## G14 — split-adjustment on Position.t Holding state (RESOLVED 2026-05-01 via PR #736)

**Resolution:** PR #736 (`fix(weinstein): G14 — entry_price = current close + lookback truncation at split boundary`) shipped Option 1 from `dev/notes/g14-deep-dive-2026-05-01.md`. Both bugs (screener split-aware lookback truncation + entry_price = current_close) fixed together. Force-liq trigger surface still exists but no longer fires spuriously on split-window symbols. See deep-dive note Status section for details.

Original filing preserved below for historical context.

---

**Symptom.** All 5 residual force-liqs in the post-G13 baseline are
`Per_position` triggers on long positions with 52–96% unrealized loss:

- ALGN: entry $554.76 → current $265.82 (-52%)
- DASH: entry $130.85 → current $58.06 (-56%)
- PANW: entry $644.10 → current $185.90 (-71%) — PANW had a 3:1 split
  Sep 2022
- GOOG: entry $2651.66 → current $106.42 (-96%) — GOOG had a 20:1
  split Jul 2022
- TECH: entry $399.33 → current $82.27 (-79%)

**Hypothesis.** `Trading_portfolio.Split_event.apply_to_portfolio`
adjusts portfolio lot quantity + cost_basis on split events, but the
strategy-side `Position.t` Holding state's `entry_price` field is not
updated. `Force_liquidation_runner._position_input_of_holding` reads
that stale `entry_price`. So a position entered pre-split at $2500
shows in FL events with `entry_price = 2651.66 / quantity = 56` even
after a 20:1 split that should have made it `entry_price = 132.58 /
quantity = 1120`. `cost_basis = entry_price * quantity` happens to be
preserved (multiplicative split is invariant on the product), but the
`unrealized_pnl = (current - entry) * qty` formula gets the wrong
answer because both `current` and `qty` are post-split-adjusted while
`entry` is not.

**Fix shape (proposed, not implemented).** Either: (a) thread split
events into a `Position.apply_split` that updates Holding's
`entry_price` and `quantity` in lockstep with the lot-side adjustment
in `Split_event.apply_to_portfolio`; (b) compute `entry_price` on the
fly from `lot.cost_basis / lot.quantity` in
`_position_input_of_holding` to bypass the stale field entirely.

**Owner.** `feat-weinstein` — strategy-side position state machine.

## G15 — short-side risk control (RESOLVED 2026-05-01 via PRs #737 + #739 + #740)

**Resolution:** Three-step fix shipped same day:
- PR #737 (G15 step-1): asymmetric per-position thresholds — long 25% / short 15%
- PR #739 (G15 step-2): aggregate short-notional cap at entry-decision time
- PR #740 (G15 step-3): pre-entry stop-width rejection + sizing-uses-installed-stop

The phantom `Portfolio_floor` cascade is gone (G12+G13) AND a real risk surface is now in place. M5.4 E1 short on/off A/B (PR #777, 2026-05-02) confirms the strategy STILL doesn't extract value from shorts in the smoke catalog (5 baseline shorts in COVID crash all losers, none in bull, 1 stuck-open in recovery) — but losses are now bounded, not unbounded.

Original filing preserved below for historical context.

---


**Symptom.** With the spurious `Portfolio_floor` cascade eliminated by
G12+G13, sp500-2019-2023 portfolio goes negative (-$175K minimum on
2021-11-04, -66.7% return, **117.5% MaxDD**). The phantom floor was
acting as an unintended risk control that prevented this — the
strategy's actual short-side risk management is inadequate.

**Hypothesis.** Shorts can lose unbounded dollars (price can rise
indefinitely), but the strategy's per-position stop-loss only fires on
50%+ unrealized loss. With many concurrent shorts in a sustained bull
market (2019-2021), losses compound past the cash buffer; the strategy
keeps opening new shorts; eventually portfolio_value goes negative.

**Fix shape (deferred).** Real risk-control candidates: (a) maximum
total short notional as fraction of portfolio; (b) tighten per-position
short stop-loss threshold (book reference: Weinstein recommends
tighter stops on shorts than longs); (c) re-introduce an HONEST
portfolio-floor based on actual peak observations (which now work
correctly post-G13). Combination of (a) + (b) likely needed.

**Owner.** `feat-weinstein` — strategy-level risk surface.

## Reference: diagnostic procedure used for G13

Added a temporary `eprintf` to `Force_liquidation_runner.update`
logging `(date, n_pos, cash, pv, peak_before, peak_after, events)`,
re-ran sp500 with G12 applied, examined the trace. The
`date=2026-05-01` (`Date.today` fallback) entries with `pv = cash`
were the smoking gun — they showed peak getting set on weekends from
the cash-only pv computation. The diagnostic pattern is reusable for
any future Peak_tracker invariant question: same logging surface,
same query for "ticks where peak_after > peak_before but the
observation looks suspicious."
