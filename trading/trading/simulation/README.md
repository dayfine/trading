# Simulation Module

## Overview
Backtesting and simulation framework for testing trading strategies using historical data and simulated market conditions.

**Implementation approach**: Daily-granularity backtesting with OHLC-based intraday execution modeling.
- Strategy runs once per day after market close
- Orders execute next day against synthetic intraday price paths
- Leverages existing `analysis/data` module for historical prices

## Current Status
✅ **Phase 1, 2 & 3: COMPLETE** - Core infrastructure, OHLC price path simulation, and daily simulation loop implemented

### Completed

**Phase 1: Core Types**
- ✅ Core types in `lib/simulator.mli`:
  - `symbol_prices` - Historical price data per symbol using `Types.Daily_price.t`
  - `config` - Simulation configuration (start/end dates, initial cash, commission)
  - `step_result` - Result of a single simulation step (date, portfolio, trades)
  - `step_outcome` - Stepped vs Completed state variants
- ✅ Simulator interface in `lib/simulator.ml`:
  - `create` - Initialize simulator from config and dependencies
  - `step` - Advance simulation by one day (currently stub implementation)
  - `run` - Execute full simulation from start to end date
- ✅ Test suite in `test/test_simulator.ml`:
  - 6 tests covering creation, stepping, and running simulations
  - All tests passing ✓

**Phase 2: OHLC Price Path Simulator**
- ✅ Price path types in `lib/price_path.mli`:
  - `path_point` - Single point on intraday path (fraction_of_day, price)
  - `intraday_path` - Complete path from open to close
  - `fill_result` - Order fill price and timing
- ✅ Path generation in `lib/price_path.ml`:
  - `generate_path` - Synthetic intraday paths from OHLC bars
  - Deterministic path generation (O→H→L→C or O→L→H→C based on direction)
  - Path touches all OHLC points in realistic order
- ✅ Order execution logic:
  - `would_fill` - Determine if/when orders execute against price path
  - Support for Market, Limit, Stop, and StopLimit orders
  - Correct fill detection for all order types
- ✅ Comprehensive test suite in `test/test_price_path.ml`:
  - 14 tests covering path generation and order fills
  - All 20 simulation tests passing ✓

**Phase 3: Daily Simulation Loop**
- ✅ Full trading logic in `lib/simulator.ml`:
  - `step` function implementation with actual order execution
  - Engine and OrderManager integration in simulator state
  - OHLC data conversion from Daily_price to price_bar
  - Multi-day order persistence (GTC orders)
  - Portfolio updates via trade application
- ✅ Order submission API:
  - `submit_orders` function for placing orders with simulator
  - Orders processed on next step with current market data
- ✅ Comprehensive test suite in `test/test_simulator.ml`:
  - Market order execution with portfolio updates
  - Limit orders executing on later days when price reached
  - Stop orders triggering across multiple days
  - Insufficient cash validation and error handling
  - All 10 simulation tests passing ✓

### In Progress
🚧 **Phase 4: Strategy Interface** - Not started

### Next Steps

#### Core Types (Additional work)
- [ ] Define `strategy_signal` type:
  - Buy/sell signals with quantities
  - Entry/exit conditions
  - Risk management parameters
- [ ] Define `simulation_result` type:
  - Portfolio performance over time
  - Trade history and statistics
  - Risk metrics (Sharpe ratio, max drawdown)
  - Execution quality metrics

### Phase 2: OHLC Price Path Simulator (`lib/price_path.mli` & `lib/price_path.ml`)
- [ ] Generate synthetic intraday price paths from daily OHLC bars
- [ ] Determine realistic order execution prices and times
- [ ] Support for market, limit, stop, and stop-limit orders
- [ ] Path generation strategies (deterministic and randomized)
- [ ] Comprehensive tests for path generation and order fills

### Phase 3: Daily Simulation Loop (enhance `lib/simulator.ml`)
- [x] Implement actual trading logic in `step` function (currently stub)
- [x] Generate intraday paths from OHLC data
- [x] Execute pending orders against price paths
- [x] Apply trades to portfolio
- [x] Integration with Engine, Portfolio, and OrderManager modules
- [x] Tests for order execution and multi-day simulations

### Phase 4: Strategy Interface (`lib/strategy.mli` & `lib/strategy.ml`)
- [ ] Define `STRATEGY` module signature
- [ ] `on_market_close` - Strategy runs after market close each day
- [ ] `order_intent` type with reasoning
- [ ] Strategy state management
- [ ] Validation that orders are priced (Limit/Stop/StopLimit, no Market)

### Phase 5: Built-in Strategies
- [ ] `BuyAndHold` - Simple baseline strategy
- [ ] `SimpleMovingAverage` - Technical indicator crossover
- [ ] `MeanReversion` - Statistical arbitrage
- [ ] Strategy parameter configuration
- [ ] Tests for each strategy's signal generation

### Phase 6: Strategy Integration
- [ ] `create_with_strategy` - Automated backtesting
- [ ] Convert order intents to orders
- [ ] Full daily loop: execute orders → call strategy → prepare next day
- [ ] Multi-symbol backtest support
- [ ] Integration tests

### Phase 7: Performance Metrics (`lib/metrics.mli` & `lib/metrics.ml`)
- [ ] Return calculations (total, annualized)
- [ ] Risk metrics (volatility, Sharpe ratio, max drawdown)
- [ ] Trade statistics (win rate, profit factor)
- [ ] Equity curve generation
- [ ] Tests for metric calculations

### Phase 8: Simulation Results & Reporting
- [ ] `simulation_result` type aggregating all outputs
- [ ] `run_backtest` - Complete backtest with full results
- [ ] Timing and performance tracking
- [ ] Result pretty-printing and export
- [ ] End-to-end tests

### Phase 9: CLI Tool & Data Integration
- [ ] `bin/simulate.ml` - Command-line interface
- [ ] Integration with `analysis/data/storage` for loading historical data
- [ ] Argument parsing for symbols, strategies, date ranges
- [ ] Output formatting (text, JSON)
- [ ] CLI integration tests

## Dependencies
- `trading.base` - Core types
- `trading.orders` - Order management
- `trading.portfolio` - Portfolio tracking
- `trading.engine` - Order execution
- `analysis.data` - Historical data access
- `core` - Standard library
- `ounit2` - Testing framework

## Key Design Decisions
1. **Event-Driven Architecture**: Time-based simulation with discrete events
2. **Strategy Modularity**: Pluggable strategy interface for different algorithms
3. **Performance Focus**: Efficient backtesting of large datasets
4. **Integration**: Reuse existing trading system components
5. **Analytics**: Comprehensive performance and risk metrics

## Integration Points & Data Flow

**Simulation is the ORCHESTRATOR** - it coordinates the entire trading workflow:

### Simulation → Engine
```ocaml
(* Generate orders from strategy signals *)
let orders = Strategy.generate_signals market_data portfolio_state in
let execution_results = Engine.execute_orders orders market_data in
```

### Simulation → Portfolio (via Engine results)
```ocaml
(* Apply execution results to portfolio *)
let trades = Engine.get_executed_trades execution_results in
let updated_portfolio = Portfolio.apply_trades portfolio trades in
```

### Simulation → Orders
```ocaml
(* Create and validate orders *)
let order_params = Strategy.generate_order_params signals in
let orders = Orders.create_orders order_params in
```

**Dependencies**:
- **Engine Module**: Execute orders in simulated environment
- **Portfolio Module**: Track portfolio performance over time
- **Orders Module**: Create and manage order lifecycle
- **Analysis Data**: Access historical market data for backtesting

## Future Enhancements
- Multi-asset strategy support
- Options and derivatives simulation
- Transaction cost modeling
- Regime-aware backtesting
- Monte Carlo simulation capabilities
- Strategy optimization frameworks