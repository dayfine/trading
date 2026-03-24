# Weinstein Trading System — Design Document v2

---

## 1. What we're building

A semi-automated trading system for a US equity portfolio (long + short) at any scale, using Stan Weinstein's stage analysis methodology. International indices for macro signals only.

**Automated:** data collection, analysis, signal generation, stop management, order generation, alerting, backtesting, parameter tuning.

**Manual:** reviewing results, deciding which signals to act on, placing limit orders while market is closed.

---

## 2. The core abstraction

The central architectural idea: **live trading and backtesting run the same pipeline**. The only difference is the data source and the execution layer.

```
                 ┌──────────────┐  ┌──────────────────┐  ┌─────────────────┐
                 │ Live data    │  │ Historical data   │  │ Synthetic data  │
                 │ (EODHD API)  │  │ (replay from cache│  │ (generated for  │
                 └──────┬───────┘  └────────┬──────────┘  │  stress testing) │
                        │                   │              └────────┬────────┘
                        └───────────┬───────┴───────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Analysis pipeline  │  ← config (parameters)
                    │  (pure functions)   │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                                 ▼
   ┌──────────────────┐              ┌──────────────────┐
   │ Live execution   │              │ Simulated exec.  │
   │ Report → you     │              │ Auto-fill orders │
   │ review → you     │              │ → performance    │
   │ place orders     │              │   metrics        │
   └──────────────────┘              └──────────┬───────┘
                                                │
                                     ┌──────────▼───────┐
                                     │ Tuner            │
                                     │ Runs N sims with │
                                     │ different configs │
                                     └──────────────────┘
```

**Why this matters:**

- Every component is tested against historical data before it touches real money.
- You can experiment with different markets, parameters, and strategy variations without risk.
- The tuner is just a loop around the simulation path — no new pipeline, no special-cased code.
- When you modify a scoring weight or a stop rule, you can immediately see how it would have performed historically.

The pipeline, the data source interface, and the execution interface are the three contracts that everything else hangs from.

---

## 3. How you use it

### 3.1 Weekly cycle (primary)

```
Friday close → system runs automatically
  ├── Fetches week's data
  ├── Runs full analysis pipeline
  ├── Generates weekly report + order suggestions
  └── Sends you a summary

Saturday morning → you review (~30 min)
  ├── Market regime: bull, bear, or neutral?
  ├── Alerts: stops hit? stage changes? regime shift?
  ├── Portfolio: exposure, P&L, risk budget
  ├── New candidates: buy + short, graded, with orders
  └── You decide: which orders to prepare

Sunday evening / Monday pre-market → you place orders
  ├── GTC limit orders (entered while market is closed)
  ├── Updated stop orders with broker
  └── Log entries in system
```

### 3.2 Mid-week adjustments

The system is not weekly-only. You can trigger a re-run at any time:

- **New opportunity spotted:** Re-run the screener on demand. If a stock breaks out mid-week, you want to know its grade and suggested order before the next weekly scan.
- **Trade executed:** When an order fills, you log it. The portfolio manager updates positions, recalculates exposure, and adjusts risk budget. This feeds back into the next analysis run.
- **Stop hit:** Daily monitor detects it, alerts you. You confirm the exit, log it, and the portfolio updates.
- **Market event:** If something significant happens (macro regime shift, sector breakdown), you can re-run the full pipeline to see how it changes your candidates and positions.

All order placement happens while the market is closed. You prepare limit orders based on the system's suggestions and queue them for the next open.

### 3.3 Backtesting (parallel to live trading, from day one)

Before trusting any signal with real money, you run it historically:

```
You ask: "How would this config have performed from 2015–2025?"

System:
  ├── Loads historical data for that period
  ├── Steps through week by week, running the same pipeline
  ├── At each step: generates candidates, simulates fills, manages stops
  ├── At the end: produces performance report
  │     win rate, avg gain, avg loss, max drawdown,
  │     profit factor, Sharpe, equity curve
  └── You compare against baseline / other configs
```

You will use backtesting both at the beginning (to validate the system before going live) and alongside real trading (to test parameter changes before applying them).

### 3.4 Tuning

The tuner searches the config space by running many backtests:

```
You define: which parameters to vary, what ranges, what objective to optimize

Tuner:
  ├── Generates candidate configs (grid search, random, or Bayesian)
  ├── For each config: runs a full backtest
  ├── Collects performance metrics
  ├── Reports: best config, sensitivity analysis, overfitting risk
  └── You review and decide whether to adopt
```

---

## 4. Components and how they interact

There are seven components. Each has a clear input contract, output contract, and responsibility. They interact through typed data, not through direct calls to each other's internals.

### 4.1 Component map

```
┌─────────────┐
│ Data Source  │ ← abstract interface: live or historical
└──────┬──────┘
       │ bar_series, index_data, ad_data, universe
       ▼
┌─────────────┐      ┌─────────────────────────┐
│ Analyzer    │ ←────│ Portfolio Manager        │
│             │      │ (current positions feed  │
└──────┬──────┘      │  back into analysis)     │
       │             └────────────┬─────────────┘
       │ market_regime,                ▲
       │ sector_states,                │ you log trades,
       │ stock_analyses                │ system updates state
       ▼                               │
┌─────────────┐                        │
│ Screener    │                        │
└──────┬──────┘                        │
       │ scored_candidates             │
       ▼                               │
┌─────────────────────────┐            │
│ Portfolio Manager       │────────────┘
│ positions, stops, risk  │
└──────┬──────────────────┘
       │ portfolio_update (positions, alerts, orders)
       ▼
┌─────────────┐
│ Order Gen.  │
└──────┬──────┘
       │ order_list (entry orders, stop orders, exit orders)
       ▼
┌─────────────┐
│ Reporter    │
└──────┬──────┘
       │ weekly report, alerts, order sheet
       ▼
   ┌───────┐
   │  You  │ ──→ log trades back into Portfolio Manager
   └───────┘
```

### 4.2 The two feedback loops

**Loop 1: Portfolio → Analyzer.** What you currently hold affects analysis. Held positions get re-analyzed every run (for stop adjustments and stage monitoring). The screener knows your portfolio — it won't suggest buying something you already hold, and it factors in exposure limits when ranking candidates.

**Loop 2: You → Portfolio Manager.** When you execute a trade (or an order fills), you log it. The portfolio manager updates positions, recalculates exposure, and this feeds into the next run.

### 4.3 Component contracts

#### Data Source (abstract interface)

This is the seam between live and simulation. Both modes implement the same interface:

```
interface DataSource:
  weekly_bars(ticker, max_weeks) → bar list
  index_bars(index, max_weeks)   → bar list
  ad_data(date_range)            → ad_record list
  universe()                     → ticker_meta list
  daily_close(ticker, date)      → float   (* for intraday stop checks *)
```

**Live implementation:** Calls EODHD API, caches to disk.

**Historical implementation:** Reads from cache. Given a "current date" parameter, returns only data that would have been available on that date (no lookahead).

**Synthetic implementation:** Generates bar series programmatically — for stress testing (crash scenarios, extreme volatility, low-liquidity regimes), edge case validation, and testing strategy behavior under conditions that haven't occurred in the historical record.

#### Analyzer

```
input:  DataSource + config + portfolio_state (what you currently hold)
output: analysis_result
  { market_regime   : regime        (* bull/bear/neutral + confidence + indicators *)
  ; sectors         : sector_state list
  ; stock_analyses  : stock_analysis list  (* one per ticker in universe *)
  ; held_analyses   : stock_analysis list  (* re-analysis of current positions *)
  }
```

Contains three parallel sub-analyzers (macro, sector, stock) that share primitives but don't call each other. Portfolio state is an input so the analyzer can prioritize re-analyzing held positions and flag stage changes.

Stateful: **no**. Pure function of inputs.

#### Screener

```
input:  analysis_result + portfolio_state + config
output: screener_result
  { buy_candidates   : scored_candidate list
  ; short_candidates : scored_candidate list
  ; watchlist        : watchlist_entry list   (* approaching breakout *)
  }
```

Implements the cascade: macro regime gates → sector filter → stock scoring. Knows about the portfolio to avoid suggesting positions you already hold and to respect exposure limits.

Stateful: **no**.

#### Portfolio Manager

```
input:  screener_result + held_analyses + config
manages: portfolio_state (persisted)
output: portfolio_update
  { positions    : position list        (* with updated stops *)
  ; alerts       : alert list           (* stops hit, stage changes, risk warnings *)
  ; stats        : portfolio_stats      (* exposure, P&L, risk budget *)
  ; suggested_orders : order list       (* what orders to generate *)
  }
```

Sub-responsibilities:
- **Position tracking:** Entry, current price, stop, stage, P&L.
- **Stop engine:** The full Weinstein trailing stop state machine (initial → trailing → tightened).
- **Risk / sizing calculator:** Given a candidate + config risk budget + stop distance → position size.
- **Exposure tracker:** Long %, short %, cash %. Warns if limits exceeded.
- **Concentration checker:** Flags sector overweight.

Stateful: **yes** — this is the only stateful component. Portfolio state persists between runs.

Also provides:
```
  log_trade(ticker, side, price, shares, date) → updated portfolio_state
  close_position(ticker, exit_price, date)     → updated portfolio_state
```

These are how you feed trades back in after manual execution.

#### Order Generator

```
input:  portfolio_update (specifically suggested_orders + positions)
output: order_list
  { entry_orders : order list    (* GTC limit buy/sell-short for new positions *)
  ; stop_orders  : order list    (* GTC sell-stop / buy-stop for held positions *)
  ; exit_orders  : order list    (* close positions where stops were hit *)
  }
```

Each order includes: ticker, side (buy/sell/short/cover), order type (limit/stop), price, shares, rationale.

**When does this generate orders?** Whenever there's a clear signal:
- New A/A+ candidate with confirmed breakout → entry order
- Trailing stop adjusted → updated stop order
- Stop hit → exit order
- Stage change on held position (e.g. Stage 2 → Stage 3) → suggested partial exit

These are **suggestions.** In live mode, you review and decide. In simulation mode, they auto-execute.

Stateful: **no**.

#### Reporter

```
input:  analysis_result + screener_result + portfolio_update + order_list
output: report (structured JSON + human-readable summary)
  ; alert_messages (for immediate notification)
  ; trade_log_entry (append to history)
```

The weekly report answers, in order:
1. Market regime and what changed
2. Alerts requiring action
3. Portfolio snapshot (positions, P&L, exposure)
4. Order sheet (what to place pre-market)
5. New candidates (buy + short, graded)
6. Sector map
7. Watchlist

Stateful: **trade history** (append-only log).

#### Simulator (wraps the pipeline for backtesting)

```
input:  config + date_range + initial_capital
output: simulation_result
  { trades       : trade list           (* every entry + exit *)
  ; equity_curve : (date * float) list  (* portfolio value over time *)
  ; metrics      : performance_metrics  (* win rate, Sharpe, drawdown, etc. *)
  ; weekly_snapshots : scan_result list (* optional: full state at each step *)
  }
```

Steps through the date range week by week:
1. Creates a historical DataSource pinned to the current simulation date
2. Runs Analyzer → Screener → Portfolio Manager → Order Generator
3. Auto-executes suggested orders at signal prices (or configurable fill model)
4. Advances to next week, repeats
5. At the end: computes aggregate metrics

Stateful: **internally** (simulated portfolio), but from the outside it's a pure function: config + date range → result.

#### Tuner (wraps the simulator)

```
input:  base_config + parameter_ranges + date_range + objective_function
output: tuning_result
  { best_config     : config
  ; all_runs        : (config * performance_metrics) list
  ; sensitivity     : parameter_sensitivity_report
  }
```

Runs the simulator N times with different configs. Can use grid search, random search, or Bayesian optimization (start simple, get fancier later).

---

## 5. Interaction patterns

### 5.1 Weekly scan (live)

```
Cron triggers scan:
  DataSource(live) → Analyzer(+portfolio_state) → Screener(+portfolio_state)
  → Portfolio Manager(update stops, check alerts)
  → Order Generator(entry + stop orders)
  → Reporter(weekly report + alerts)
  → You
```

### 5.2 Mid-week re-run

```
You trigger manually:
  Same pipeline as above, but against current data.
  Portfolio Manager uses latest portfolio_state (including any trades logged since last scan).
```

### 5.3 Trade logged

```
You: "AAPL filled at $152, 200 shares"
  → Portfolio Manager: log_trade("AAPL.US", Long, 152.0, 200, "2026-03-24")
  → Portfolio state updated
  → Next run will include AAPL in held positions, compute stop, check exposure
```

### 5.4 Daily stop check

```
Cron triggers monitor:
  DataSource(live, just held tickers) → for each position: check daily_close vs stop
  → If any stop hit: alert you immediately
  → If not: no output
```

### 5.5 Backtest

```
You: "weinstein backtest --from 2018-01-01 --to 2025-12-31 --config my_config.json"
  Simulator:
    for each week in range:
      DataSource(historical, pinned to week) → same pipeline → auto-execute orders
    → simulation_result with equity curve + metrics
```

### 5.6 Tune

```
You: "weinstein tune --param scoring.volume_strong:1-5 --param analysis.ma_period:20-40 ..."
  Tuner:
    for each candidate config:
      run Simulator(config, date_range)
      collect metrics
    → tuning_result with best config + sensitivity
```

---

## 6. Config — the parameter surface

Everything tunable lives in one config. Nothing hardcoded. This is what the tuner optimizes, what the backtester varies, and what you adjust as you gain experience.

Organized by component:

```yaml
analysis:
  ma_period: 30
  ma_weighted: true
  ma_slope_threshold: 0.005
  volume_breakout_ratio: 2.0
  rs_benchmark: "GSPC.INDX"
  resistance_lookback: 130        # weeks

screening:
  min_grade: B
  scoring_weights: { ... }        # every factor + weight
  
portfolio:
  risk_per_trade_pct: 1.5
  max_positions: 12
  max_long_exposure_pct: 80
  max_short_exposure_pct: 40
  min_cash_pct: 10
  max_sector_concentration: 3
  big_winner_multiplier: 2.0      # extra allocation for triple-confirm

macro:
  momentum_index_period: 200
  global_indices: [FTSE, N225, GDAXI, FCHI, AXJO]

universe:
  exchanges: ["US"]               # extensible
  min_price: 5.0
  min_avg_weekly_volume: 100000

simulation:
  fill_model: "signal_price"      # or "next_open", "vwap", etc.
  slippage_bps: 10
  commission_per_trade: 0.0

tuning:
  method: "grid"                  # or "random", "bayesian"
  objective: "sharpe"             # or "profit_factor", "max_drawdown"
  folds: 3                        # walk-forward validation
```

---

## 7. Milestones

Milestones mark the points where you gain new capability — not just "code compiles" but "I can do something I couldn't before."

### Milestone 1: Single-Stock Analyst (after P1)

**You can:** Run `weinstein analyze AAPL.US` and get back a complete analysis of any individual stock — its current stage, whether it's near a breakout, volume confirmation quality, relative strength vs the market, overhead resistance grade, and suggested stop level.

**What this enables:**
- Validate the system's analysis against your own chart reading
- Spot-check any ticker on demand
- Start building intuition for how the classifier behaves
- Compare the system's stage calls against the book's examples

**What it doesn't do yet:** No macro context, no sector filtering, no screening the full universe.

### Milestone 2: Market Context (after P2)

**You can:** Run `weinstein macro` to see the current market regime (bullish/bearish/neutral with indicator breakdown) and `weinstein sector` to see which sectors are strong, weak, or transitioning.

**What this enables:**
- Know whether to be aggressive (buying) or defensive (raising cash, looking for shorts)
- Identify which sectors to focus on before looking at individual stocks
- Get the "forest" view that gates everything else

**Combined with M1:** You can now manually apply the full Weinstein three-layer filter — check macro, check sector, then analyze individual stocks from favorable sectors. It's manual, but the analysis is automated.

### Milestone 3: Automated Screening (after P3)

**You can:** Run `weinstein scan` and get a ranked list of buy and short candidates across the entire US equity universe, graded A+ through F, with suggested entries, stops, and risk percentages.

**What this enables:**
- Your Saturday morning workflow begins. Run the scan, review candidates, decide which to act on.
- Stop manually scanning hundreds of charts — the system surfaces the best setups
- Each candidate comes with a rationale explaining why it scored the way it did

**What it doesn't do yet:** No position tracking, no trailing stop management, no portfolio awareness. You're using it as a screener, not as a portfolio manager.

### Milestone 4: Position Management (after P4)

**You can:** Log your trades with `weinstein enter AAPL --price 152 --shares 200 --stop 137`, and the system tracks your positions, computes trailing stops, monitors for stop hits, and alerts you when something needs attention.

**What this enables:**
- The full weekly cycle: scan → enter positions → system manages stops → alerts on exits
- Position sizing: the system tells you how many shares to buy given your risk budget
- Portfolio awareness: exposure tracking, sector concentration warnings
- No more manually tracking where your stops should be — the system implements Weinstein's trailing stop state machine mechanically

**Combined with M3:** The screener now knows what you hold and won't suggest buying something you already own. It factors your exposure limits into candidate rankings.

### Milestone 5: Historical Backtesting (after P6)

**You can:** Run `weinstein backtest --from 2015-01-01 --to 2025-12-31` and get a full performance report — equity curve, Sharpe ratio, max drawdown, win rate, trade log.

**What this enables:**
- Validate the system before risking real money (or validate it alongside real trading)
- Test the strategy across different market regimes (bull, bear, sideways)
- Compare different time periods to understand when Weinstein's approach works best
- Build confidence (or identify weaknesses) in the approach

**Combined with M4:** You can now run the system in parallel — live trading with real positions while backtesting parameter variations on the side.

### Milestone 6: Full Automated Cycle (after P5)

**You can:** Set up a cron job and the system runs automatically: weekly scan on Friday close, daily stop monitoring, alerts sent to you, weekly report generated and waiting for you Saturday morning.

**What this enables:**
- Zero effort during the week unless an alert fires
- The Saturday review session is structured: open the report, check alerts, review candidates, decide, place orders
- Trade history accumulates, giving you a record to review and learn from

**This is the system described in §3 — the target operating state.**

### Milestone 7: Parameter Optimization (after P7)

**You can:** Run `weinstein tune --param analysis.ma_period:20-40 --param screening.volume_breakout_ratio:1.5-3.0 --objective sharpe` and the system searches the config space, running hundreds of backtests, and reports the best configuration with sensitivity analysis.

**What this enables:**
- Empirically optimize scoring weights, MA periods, stop thresholds
- Understand which parameters matter most (sensitivity) and which don't
- Detect overfitting risk before applying new parameters to live trading
- Experiment with strategy variations (e.g. "what if I use 20-week MA instead of 30?")

### Milestone summary

```
M1  Single-Stock Analyst    P1          Analyze any ticker on demand
M2  Market Context          +P2         Macro regime + sector health
M3  Automated Screening     +P3         Weekly scan → ranked candidates
M4  Position Management     +P4         Full portfolio tracking + stops
M5  Historical Backtesting  +P6         Backtest over any date range
M6  Full Automated Cycle    +P5         Cron → report → review → trade
M7  Parameter Optimization  +P7         Tune config against history
```

Each milestone is independently valuable. You could stop at M3 and have a useful screener. You could stop at M4 and have a complete manual trading system. M5+ adds simulation and optimization on top.

---

## 8. Build plan

Ordered by what gets you to a usable system fastest. Backtesting and tuning are designed from the start but can be implemented slightly later because they use the same pipeline.

| Phase | What | You can do after this |
|-------|------|----------------------|
| **P1: Foundation** | Config, domain types, data source interface, EODHD client + cache, MA engine, stage classifier | Analyze any single stock: `weinstein analyze AAPL.US` |
| **P2: Analysis** | RS calculator, breakout/volume detector, resistance mapper, macro analyzer, sector analyzer | Query macro regime, sector health, full stock analysis |
| **P3: Screener + orders** | Cascade filter, scoring engine, watchlist, order generator | Weekly scan producing ranked candidates with suggested orders |
| **P4: Portfolio** | Position state, trailing stop engine, sizing, exposure, concentration, trade logging | Track your portfolio, get stop alerts, mid-week adjustments |
| **P5: Reporter + automation** | Weekly report, daily monitor, alert dispatch, cron integration | Full automated weekly cycle as described in §3 |
| **P6: Simulator** | Historical DataSource, week-by-week replay, simulated fills, performance metrics | Backtest any config over any date range |
| **P7: Tuner** | Config search, multi-backtest orchestration, sensitivity analysis | Optimize parameters against historical data |

**Key design point:** P6 doesn't require new analysis code. The simulator reuses the exact same Analyzer, Screener, Portfolio Manager, and Order Generator from P2–P4. It just wires them to a historical DataSource and auto-executes orders instead of reporting them.

---

## 9. Next steps

This document establishes the top-level design: what we're building, how it's used, what the components are, and how they interact. The engineering design docs cover each subsystem in detail:

- [Data Layer](eng-design-1-data-layer.md) — EODHD client, DATA_SOURCE abstraction, cache
- [Screener / Analysis](eng-design-2-screener-analysis.md) — Stage classifier, macro/sector analysis, scoring
- [Portfolio / Stops](eng-design-3-portfolio-stops.md) — Weinstein trailing stops, risk management, order generation
- [Simulation / Tuning](eng-design-4-simulation-tuning.md) — Weekly simulation, strategy module, parameter tuner

The [Book Reference](weinstein-book-reference.md) contains the domain rules extracted from Weinstein's book — the specific criteria to encode in the analysis modules.
