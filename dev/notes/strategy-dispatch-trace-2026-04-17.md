# Strategy-dispatch trace — six-year goldens-small scenario

**Date:** 2026-04-17
**Author:** feat-backtest agent (diagnostic session)
**Artefact referenced:** `dev/backtest/scenarios-2026-04-17-184456/six-year-2018-2023/`
  (summary: universe_size=302, n_round_trips=10, wincount=89, losscount=157,
  final_portfolio_value 2.09M, unrealized_pnl 1.54M)
**Baseline pin under investigation:** PR #399, `total_trades [3, 15]` on
  `goldens-small/six-year-2018-2023.sexp`.

## Summary (TL;DR)

**Classification: BUG + EXPECTED (mixed).** The headline observation ("only 10
trades across 6 years") is the *compound* outcome of three interacting
behaviours, one of which is a real bug:

1. **Macro is *never* Bearish in 2018-2023.** The confidence score never drops
   below ~0.33, so the `Bearish` gate in `weinstein_strategy.ml:206` is never
   the blocker. 265 Bullish weeks / 67 Neutral / 0 Bearish over 332 Fridays.
   (Neutral still allows buys; see `screener.ml:413` `buys_active`.)
2. **The strategy keeps generating entries every year** — 64 total
   `CreateEntering` transitions from 2018 through 2023 (not zero after
   2019-02-25 as observed at the trades.csv level). The entries dwindle
   because the *pool of eligible symbols* shrinks, not because macro or
   sector gates reject them.
3. **BUG — `_held_symbols` returns ALL position states, not just active
   ones** (`weinstein_strategy.ml:119-120`). A position that closed on day N
   remains in `portfolio.positions` with state `Closed` forever. Its symbol
   keeps appearing in `held_tickers` passed to the screener
   (`weinstein_strategy.ml:200`) and in the in-strategy
   `List.mem held c.ticker` filter (`:135`). Net effect: **every symbol the
   strategy has ever traded becomes permanently blacklisted**. With a
   302-symbol universe and positions closing monotonically (count climbs to
   245 Closed + 43 Entering + 7 Holding = 295 / 302 by 2023-12), the
   investable universe collapses to ~7 symbols by end-of-run.

PR #399's `total_trades [3, 15]` pin captures the 7-10 round-trip range you
see in `trades.csv`, but **the interpretation on the pin is wrong**: it is
not measuring Weinstein-regime holding behaviour; it is measuring the rate
at which the first-closed positions are paired back up in `Metrics.extract_round_trips`
before the blacklist shuts the strategy down. A real fix (change
`_held_symbols` to only include Entering/Holding/Exiting) should be
expected to push the round-trip count up by an order of magnitude and
invalidate the pin's ceiling.

There is also a **secondary bug** in the bookkeeping layer (not causal to
the task observation, but flagged for clarity): the simulator's
`_is_trading_day` filter in `trading/trading/backtest/lib/runner.ml:28-36`
drops many days where trades happened, because on those days
`portfolio_value ≈ cash` when the only non-`Holding` positions have the
state `Entering`/`Closed` (which contribute `0.0` to `Portfolio_view.portfolio_value`).
This explains the `n_round_trips=10` (`trades.csv`) vs `wincount+losscount=246`
(`summary.sexp.metrics`) discrepancy — the summary path counts all trades,
the trades.csv path counts only trades on days the filter let through.

## Reject-reason histogram by year

Measured from a fresh instrumented run over 2018-01-02 → 2023-12-29 with
302-symbol small universe (`universe_path: universes/small.sexp`). Warmup
2017-06 onwards logged but only data after `start_date` aggregated below.
"Rejected_cash" is the only rejection firing; `reject=zero_shares` and
`reject=bearish_macro` counts are identically zero.

| Year | Fridays | buy_candidates (cumulative across Fridays) | entries submitted | rejected (insufficient_cash) |
| --- | ---: | ---: | ---: | ---: |
| 2018 | 51 | 159 | 28 | 131 |
| 2019 | 51 |  94 |  7 |  87 |
| 2020 | 49 |  32 | 12 |  20 |
| 2021 | 50 |  17 |  5 |  12 |
| 2022 | 51 |  12 |  6 |   6 |
| 2023 | 50 |   7 |  6 |   1 |
| **Total** | **302** | **321** | **64** | **257** |

Key: `buy_candidates` already excludes held tickers (screener cascade
applies `held_tickers` before scoring), so the drop from 159 → 7 reflects
the *universe collapse* driven by the held-tickers-include-closed bug, not
screener sensitivity.

Three most common reject reasons:

| # | Reason | Share of rejections |
| - | --- | ---: |
| 1 | `insufficient_cash` | 100% (257/257) |
| 2 | `zero_shares`       | 0% (0/257) |
| 3 | `bearish_macro`     | 0% (0/257) |

## Macro-state timeline

332 Fridays instrumented (2017-06-09 through 2023-12-29). By year:

| Year | Bullish | Neutral | Bearish |
| --- | ---: | ---: | ---: |
| 2017 (warmup) | 26 |  4 | 0 |
| 2018 | 40 | 11 | 0 |
| 2019 | 45 |  6 | 0 |
| 2020 | 38 | 11 | 0 |
| 2021 | 50 |  0 | 0 |
| 2022 | 16 | 35 | 0 |
| 2023 | 50 |  0 | 0 |

Sample transitions (`macro=<state>`, `conf=<weighted-confidence>`):

- 2018-02 pullback: stays `Bullish` with conf ≥ 0.65 throughout; no regime
  change recorded.
- 2018-10–11 bear market: flips to `Neutral` briefly, returns `Bullish`.
- 2020-03 COVID crash: flips to `Neutral` (never Bearish), resumes
  `Bullish` by 2020-06.
- 2022 bear market: `Neutral` for 35 of 51 weeks — the most sustained
  "defensive" stretch. **Still no Bearish.**

The macro model's `Bearish` bucket is effectively unreachable with the
current weight/threshold combination for the 2018-2023 data, because
`default_indicator_weights` sums to 10.0 and `default_config.bearish_threshold
= 0.35` — i.e. weighted bearish share would have to exceed 65% for the
confidence ratio `1 - (bullish_weight / total_weight)` to cross 0.35. Even in
March 2020, multiple weight-bearing indicators (momentum, global markets)
stayed `Neutral` rather than flipping negative fast enough.

This is orthogonal to the PR #399 question, but worth flagging:
**`Bearish` being unreachable is itself a suspicious calibration finding.**
See `docs/design/eng-design-2-screener-analysis.md` §Macro for the intended
regime distribution — the reference table suggests `Bearish` should fire
during sustained drawdowns, not only during end-of-cycle panic.

## Portfolio saturation curve (Entering / Holding / Closed over time)

Selected snapshots (`enter/hold/closed` position counts):

| Date | Held (total) | Entering | Holding | Closed |
| --- | ---: | ---: | ---: | ---: |
| 2018-01-12 |  24 | 10 | 13 |   1 |
| 2018-02-09 |  51 | 18 | 14 |  19 |
| 2018-07-20 | 105 | 31 | 19 |  55 |
| 2019-02-22 | 170 | 38 | 16 | 116 |
| 2020-06-05 | 252 | 39 | 13 | 200 |
| 2022-01-07 | 284 | 39 |  8 | 237 |
| 2023-12-22 | 295 | 43 |  7 | 245 |

Two things jump out:

1. **`Closed` grows monotonically to 245.** Every exit (stop_loss, etc.)
   leaves the position in the `Closed` state in `Portfolio.positions`, and
   its symbol remains in `_held_symbols` output. This is the blacklist
   mechanism driving `buy_candidates` → 0.
2. **`Entering` climbs to 43 and never flushes.** These are `CreateEntering`
   transitions whose market orders never filled (the position sits in
   `Entering` state waiting for an EntryFill that never arrives). The
   symbol is also in `held`, so no fresh order is placed for that symbol.
   (Possible secondary cause: the order's next-day fill price differs from
   `suggested_entry`; actual cost exceeds available cash at fill time;
   `Portfolio.apply_single_trade` returns `Error` on
   `_check_sufficient_cash`; the simulator drops the trade via
   `_apply_trades_best_effort`. The `Entering` position is now orphaned.)

`_held_symbols` should filter to `Entering | Holding | Exiting` states and
exclude `Closed` — see recommendation below.

## Root cause classification: BUG (primary) + EXPECTED (secondary)

**BUG** — `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml:119-120`

```ocaml
let _held_symbols (portfolio : Portfolio_view.t) =
  Map.data portfolio.positions |> List.map ~f:(fun (p : Position.t) -> p.symbol)
```

Should be:

```ocaml
let _held_symbols (portfolio : Portfolio_view.t) =
  Map.data portfolio.positions
  |> List.filter ~f:(fun (p : Position.t) ->
       match p.state with
       | Position.Entering _ | Position.Holding _ | Position.Exiting _ -> true
       | Position.Closed _ -> false)
  |> List.map ~f:(fun (p : Position.t) -> p.symbol)
```

This is referenced from two call sites (`weinstein_strategy.ml:146` and
`:200`) — both want "symbols I currently hold a position in", not "symbols
I've ever touched". Fix is a 1-function change.

**Minimal reproduction** — run the existing
`trading/test_data/backtest_scenarios/goldens-small/six-year-2018-2023.sexp`
with the 302-symbol universe. Instrument `weinstein_strategy.ml` with
per-Friday logging of `_state_breakdown portfolio` (count positions per
state) and observe the `Closed` count climbing monotonically while
`buy_candidates` approaches zero.

**EXPECTED** — PR #399's `total_trades [3, 15]` range does capture the
current observed behaviour (7-10 round trips in `trades.csv`), but it is
not protecting what the commenters claim it is protecting. After the
`_held_symbols` fix lands, expect `total_trades` to rise into the 50-100+
range. The PR #399 pin should therefore be treated as a *temporary
fingerprint of the bug* rather than a durable regression gate. Do not
pre-emptively widen it to accommodate the bugged ceiling.

## Follow-up recommendations

1. **Fix `_held_symbols` first, then re-pin goldens-small.** Filed as a
   feat-weinstein item (not this dispatch — diagnosis-only).
2. **Audit the macro calibration.** `Bearish` never firing in 2020-03 or
   2022 is unexpected for a Weinstein model; compare the weighted-sum math
   in `macro.ml` against `eng-design-2-screener-analysis.md` §Macro. File
   as a `feat-screener` item.
3. **Investigate the `_is_trading_day` filter in
   `backtest/lib/runner.ml`.** It collapses steps where only non-`Holding`
   positions exist, losing ~95% of trade events from `trades.csv` relative
   to the summary metrics. Either the filter should check for *any* state
   transition on the day, or `Portfolio_view.portfolio_value` should
   include Entering positions at cost. File as a `feat-backtest` item.
4. **Extend `Backtest.Result_writer.write` to emit a `positions.csv`** of
   per-position lifecycle (created, entry_filled, exit_filled, closed,
   state_at_end) so future diagnostics can skip the instrumentation dance.

## Raw log excerpt (representative)

Instrumentation: temporary `Printf.eprintf` lines inserted in
`weinstein_strategy.ml` at four points (`_make_entry_transition`,
`_check_cash_and_deduct`, `_entries_from_candidates`, `_run_screen`,
`_screen_universe`). All removed before commit; `jj diff --stat` on
final commit contains only this note.

```
WDIAG date=2018-01-05 macro=Bullish conf=1.000 indicators=[Index Stage=+,A-D Line=+,Momentum Index=+,NH-NL=+,Global Markets=0]
WDIAG date=2018-01-05 stocks_analyzed=293 buy_candidates=20 short_candidates=0 watchlist=8
WDIAG date=2018-01-05 symbol=MU   reject=insufficient_cash cost=124971 cash=252
WDIAG date=2018-01-05 symbol=CFG  reject=insufficient_cash cost=124974 cash=252
WDIAG date=2018-01-05 held=0 enter=0 hold=0 exit=0 closed=0 pv=1000000 cash=1000000 cand_in=20 after_held=20 after_size=20 after_cash=8

WDIAG date=2019-02-22 macro=Bullish conf=0.727 indicators=[Index Stage=0,A-D Line=+,Momentum Index=+,NH-NL=0,Global Markets=-]
WDIAG date=2019-02-22 stocks_analyzed=293 buy_candidates=12 short_candidates=0 watchlist=0
WDIAG date=2019-02-22 symbol=MMM  reject=insufficient_cash cost=139751 cash=127659
WDIAG date=2019-02-22 symbol=CHTR reject=insufficient_cash cost=139631 cash=127659
WDIAG date=2019-02-22 held=170 enter=38 hold=16 exit=0 closed=116 pv=1118170 cash=127659 cand_in=12 after_held=12 after_size=12 after_cash=0

WDIAG date=2020-03-20 macro=Neutral conf=0.500 indicators=[Index Stage=-,A-D Line=0,Momentum Index=0,NH-NL=0,Global Markets=0]
WDIAG date=2020-03-20 stocks_analyzed=293 buy_candidates=0 short_candidates=0 watchlist=0
WDIAG date=2020-03-20 held=230 enter=38 hold=5 exit=0 closed=187 pv=806912 cash=604320 cand_in=0 after_held=0 after_size=0 after_cash=0

WDIAG date=2022-02-18 macro=Neutral conf=0.350 indicators=[Index Stage=0,A-D Line=-,Momentum Index=0,NH-NL=-,Global Markets=-]
WDIAG date=2022-02-18 stocks_analyzed=293 buy_candidates=0 short_candidates=0 watchlist=0
WDIAG date=2022-02-18 held=286 enter=39 hold=13 exit=0 closed=234 pv=2197847 cash=544987 cand_in=0 after_held=0 after_size=0 after_cash=0

WDIAG date=2023-12-22 macro=Bullish conf=1.000 indicators=[Index Stage=+,A-D Line=+,Momentum Index=+,NH-NL=+,Global Markets=+]
WDIAG date=2023-12-22 stocks_analyzed=298 buy_candidates=0 short_candidates=0 watchlist=0
WDIAG date=2023-12-22 held=295 enter=43 hold=7 exit=0 closed=245 pv=2095553 cash=553073 cand_in=0 after_held=0 after_size=0 after_cash=0
```
