# Milestone Integration Tests

Each milestone (M1-M7) defines a user-facing capability ("You can: ..."). This document specifies an integration test for each milestone that proves the capability works end-to-end. These are not unit tests — they exercise the full pipeline for each milestone's scope.

**Owner**: feat-weinstein agent (M1-M5), future agents for M6-M7.

**Location**: Tests live alongside the components they exercise — not in a single milestone directory. A milestone test may be a new file in an existing test directory (e.g. `screener/test/test_e2e.ml`) or extend an existing test file. The naming should reflect what's being tested (e.g. "component test", "end-to-end test"), not which milestone number it demonstrates. This document is a checklist ensuring coverage exists, not a prescription for file layout.

**Data**: Real cached data where available (AAPL, GSPC.INDX, GDAXI.INDX, N225.INDX); synthetic data only where real data cannot demonstrate the capability.

**Convention**: Each milestone's capability should be covered by 2-5 tests. Tests should be readable as a demonstration of the capability — someone unfamiliar with the code should understand what the system does by reading the test.

---

## M1: Single-Stock Analyst

**"You can analyze any individual stock — its current stage, breakout proximity, volume confirmation, relative strength, overhead resistance, and suggested stop level."**

### Tests

1. **Full analysis of AAPL in a known bull market (2023-Q4)**
   - Load real AAPL weekly bars from CSV cache
   - Load real GSPC.INDX bars as market reference
   - Call `Stock_analysis.analyze` with full config
   - Assert: stage = Stage2, RS > 0, volume confirmation is not None, resistance grade is not None, suggested stop level < current price

2. **Full analysis of AAPL in a known bear market (2022-Q3)**
   - Same pipeline, different date range
   - Assert: stage = Stage4 or Stage3, RS reflects underperformance or market-relative weakness

3. **All output fields are populated**
   - Run analysis on any period with sufficient data
   - Assert every field in the result record is non-default (no None where a value is expected, no 0.0 placeholders)

### Dependencies
- `Stock_analysis.analyze` (screener module)
- `Historical_source` or direct CSV loading
- Real AAPL + GSPC.INDX data (both cached)

---

## M2: Market Context

**"You can see the current market regime (bullish/bearish/neutral) and which sectors are strong or weak."**


### Tests

1. **Macro analysis — 2022 bear market**
   - Load GSPC.INDX bars for 2022
   - Call `Macro.analyze` with real index data
   - Assert: regime = Bearish (or score < neutral threshold)

2. **Macro analysis — 2023 bull market**
   - Load GSPC.INDX bars for 2023-2024
   - Assert: regime = Bullish (or score > neutral threshold)

3. **Macro analysis degrades gracefully with missing data**
   - Call with `ad_bars:[]` and `global_index_bars:[]`
   - Assert: still returns a valid result (not an error), regime is determined from primary index alone

4. **Sector analysis — relative strength ranking**
   - Construct sector data from cached symbols (or synthetic if real sector ETFs not cached)
   - Call `Sector.analyze`
   - Assert: returns a non-empty sector ranking, each sector has an RS score

### Dependencies
- `Macro.analyze`, `Sector.analyze`
- GSPC.INDX data (cached), optionally GDAXI.INDX / N225.INDX for global index bars
- Sector ETF data (may need fetching — see ops-data follow-up)

---

## M3: Automated Screening

**"You can run a weekly scan and get a ranked list of buy and short candidates, graded, with suggested entries, stops, and risk percentages."**


### Tests

1. **Full screener cascade — bullish market, mixed-stage universe**
   - Construct a small universe: 5-10 real stocks with cached data spanning diverse stages
   - Set macro to bullish (from real GSPC.INDX data or constructed)
   - Run `Screener.screen` (full cascade: macro gate -> sector filter -> individual scoring -> ranking)
   - Assert: at least 1 buy candidate returned, candidates are ranked by grade, each candidate has entry price, stop level, and risk percentage

2. **Bearish macro gates all buy candidates**
   - Same universe, but macro = bearish
   - Assert: 0 buy candidates returned (macro gate is unconditional)
   - Assert: short candidates may still be present

3. **Candidate output completeness**
   - For each returned candidate, assert: ticker, grade, entry price, stop level, risk %, rationale string are all populated

4. **Stage4 short candidate detection**
   - Include a stock in Stage 4 decline
   - Assert: it appears as a short candidate with appropriate stop level above current price

### Dependencies
- `Screener.screen` (full cascade)
- `Macro.analyze`, `Sector.analyze`, `Stock_analysis.analyze`
- Real multi-stock data (AAPL + 4-9 others — check what's cached with enough history)

---

## M4: Position Management

**"You can track positions, compute trailing stops, monitor for stop hits, and get alerts when something needs attention."**


### Tests

1. **Full position lifecycle: entry -> trailing stop -> exit**
   - Start with a screener buy candidate (from M3 output or constructed)
   - Create a position via `Position.transition` (CreateEntering)
   - Feed weekly bars over 10-20 weeks where price rises, then declines
   - Assert: stop trails upward as price advances (never lowered)
   - Assert: stop eventually triggers when price drops below stop level
   - Assert: TriggerExit transition is emitted

2. **Order generation for position lifecycle**
   - Feed the transitions from test 1 through `order_gen.from_transitions`
   - Assert: CreateEntering -> StopLimit buy order
   - Assert: UpdateRiskParams -> Stop order at correct stop level (for each weekly update)
   - Assert: TriggerExit -> no broker order (GTC stop already at broker)

3. **Position sizing respects portfolio risk**
   - Given a portfolio value and risk budget (e.g. 2% max risk per position)
   - Call `Portfolio_risk.compute_position_size`
   - Assert: computed size * (entry - stop) / portfolio_value <= max_risk_pct

4. **Portfolio exposure limits**
   - Create multiple positions approaching concentration limits
   - Call `Portfolio_risk.check_limits`
   - Assert: warnings/blocks when sector concentration or total exposure exceeded

### Dependencies
- `Position` transitions, `Weinstein_stops`, `order_gen`, `Portfolio_risk`
- Real or synthetic price bars for the lifecycle progression

---

## M5: Historical Backtesting

**"You can backtest over any date range and get a performance report — equity curve, Sharpe ratio, max drawdown, win rate, trade log."**


**Blocked on**: Simulation Slice 3 (trade assertions require screener-aware synthetic data).

### Tests

1. **Full Weinstein backtest on real data (2020-2024)**
   - Run `Simulator.run` with `Weinstein_strategy` on real AAPL + GSPC.INDX data
   - Assert: at least 1 trade executed (entry + exit)
   - Assert: final equity > 0 (strategy didn't blow up)
   - Assert: trade log is non-empty, each trade has entry/exit dates and prices

2. **Backtest across different regimes**
   - Run on 2022 (bear) vs 2023-2024 (bull)
   - Assert: bull period has more trades than bear period
   - Assert: bear period generates short candidates or stays mostly in cash

3. **Performance metrics are computed**
   - From the backtest result, extract: total return, max drawdown, trade count, win rate
   - Assert: all are finite numbers (no NaN/infinity), drawdown is negative, trade count > 0

4. **Date range is respected**
   - Run with `--from 2023-01-01 --to 2023-12-31`
   - Assert: no trades outside the specified range
   - Assert: equity curve starts at initial capital on start date

### Dependencies
- `Simulator.run`, `Weinstein_strategy`
- Real AAPL + GSPC.INDX data (cached)
- Simulation Slice 2 (done) + Slice 3 (pending — trade assertions)

---

## M6: Full Automated Cycle (future — P5 not built)

**"You can set up a cron job: weekly scan on Friday close, daily stop monitoring, alerts, weekly report."**


### Tests (planned, not implementable yet)

1. **Weekly report generation** — run scan, produce structured report with candidates + portfolio status
2. **Daily stop monitoring** — given positions, check for stop breaches, produce alert list
3. **Alert dispatch** — verify alert format and delivery mechanism
4. **End-to-end weekly cycle** — simulate Friday close -> scan -> report -> Monday review

---

## M7: Parameter Optimization (future — P7 not built)

**"You can tune parameters against history and get the best configuration with sensitivity analysis."**


### Tests (planned, not implementable yet)

1. **Config comparison** — given 2 configs, run backtests on each, identify the better performer
2. **Sensitivity analysis** — vary one parameter, verify performance curve is smooth
3. **Overfitting detection** — in-sample vs out-of-sample performance comparison

---

## Implementation Plan

### Phase 1: M1 + M2 (can start now)
- All analysis modules exist and are tested at the unit level
- Real AAPL + GSPC.INDX data is cached
- Estimated: 2 commits, ~300-400 lines total

### Phase 2: M3 + M4 (can start now, may need additional cached data)
- Screener cascade exists; need to verify multi-stock data availability
- Position lifecycle components (stops, order_gen, portfolio_risk) all exist
- Estimated: 2-3 commits, ~400-500 lines total

### Phase 3: M5 (after Simulation Slice 3)
- Blocked on screener-aware synthetic data for trade assertions
- Once Slice 3 lands, this test is straightforward
- Estimated: 1-2 commits, ~200-300 lines

### Phase 4: M6, M7 (after P5, P7 feature work)
- Deferred until the underlying features exist

### Assignment
All milestone tests are assigned to the **feat-weinstein** agent. The orchestrator should dispatch M1+M2 tests in the next run after this plan is approved. M3+M4 follow immediately after. M5 is gated on Slice 3.

### Ops-data prerequisites
- AAPL: cached through 2025-05-16 (OK)
- GSPC.INDX: cached, 24,684 bars (OK)
- GDAXI.INDX: cached, 11,838 bars (OK)
- N225.INDX: cached, 15,735 bars (OK)
- Multi-stock universe for M3: verify which symbols have sufficient history (ops-data task)
- FTSE.INDX: not available on EODHD; use ISF.LSE proxy or skip
- Stale data: all symbols end at 2025-05-16; refresh needed before live runs
- `fetch_universe.exe`: not yet built; needed for sector metadata in M3 sector filter
- NYSE A-D breadth: not yet available; M2 macro test should verify graceful degradation with `ad_bars:[]`
