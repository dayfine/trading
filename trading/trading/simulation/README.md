# Simulation Module

## Overview
Backtesting and simulation framework for testing trading strategies using historical data and simulated market conditions.

## Current Status
🚧 **SCAFFOLDED** - Only directory structure exists

## TODO

### Core Types (`lib/types.mli` & `lib/types.ml`)
- [ ] Define `simulation_config` type:
  - Start/end dates for simulation period
  - Initial portfolio value and cash
  - Commission and fee structure
  - Market data source configuration
- [ ] Define `simulation_state` type:
  - Current simulation timestamp
  - Active orders, portfolio state
  - Performance metrics accumulator
  - Market data context
- [ ] Define `strategy_signal` type:
  - Buy/sell signals with quantities
  - Entry/exit conditions
  - Risk management parameters
- [ ] Define `simulation_result` type:
  - Portfolio performance over time
  - Trade history and statistics
  - Risk metrics (Sharpe ratio, max drawdown)
  - Execution quality metrics

### Strategy Framework (`lib/strategy.mli` & `lib/strategy.ml`)
- [ ] **Strategy Interface**:
  - `strategy` abstract type for trading algorithms
  - `generate_signals` - Produce trading signals from market data
  - `risk_check` - Validate signals against risk constraints
  - `update_state` - Maintain strategy-specific state
- [ ] **Built-in Strategies**:
  - `buy_and_hold_strategy` - Simple baseline strategy
  - `moving_average_strategy` - Technical indicator based
  - `mean_reversion_strategy` - Statistical arbitrage
- [ ] **Strategy Utilities**:
  - `create_custom_strategy` - Strategy builder interface
  - `combine_strategies` - Portfolio of strategies
  - Signal aggregation and conflict resolution

### Simulation Engine (`lib/simulator.mli` & `lib/simulator.ml`)
- [ ] **Simulation Core**:
  - `create_simulation` - Initialize simulation environment
  - `run_simulation` - Execute full backtest
  - `step_simulation` - Single time step execution
  - `get_simulation_state` - Current state inspection
- [ ] **Time Management**:
  - `advance_time` - Move simulation clock forward
  - `handle_market_hours` - Trading session management
  - `process_time_based_events` - Expiry, dividends, etc.
- [ ] **Event Processing**:
  - `process_strategy_signals` - Convert signals to orders
  - `execute_orders` - Use trading engine for execution
  - `update_portfolio` - Apply execution results
  - `collect_metrics` - Performance tracking

### Historical Data Integration (`lib/data.mli` & `lib/data.ml`)
- [ ] **Data Loading**:
  - `load_historical_prices` - Import price data
  - `validate_data_quality` - Check for gaps, errors
  - `preprocess_data` - Clean and normalize data
- [ ] **Data Access**:
  - `get_prices_at_time` - Historical price lookup
  - `get_price_range` - Time series data extraction
  - `interpolate_missing_data` - Handle data gaps
- [ ] **Data Sources**:
  - CSV file import
  - Integration with existing analysis/data modules
  - Mock data generation for testing

### Performance Analytics (`lib/analytics.mli` & `lib/analytics.ml`)
- [ ] **Return Calculations**:
  - `calculate_returns` - Portfolio returns over time
  - `calculate_benchmark_returns` - Compare to benchmark
  - `calculate_risk_adjusted_returns` - Sharpe, Sortino ratios
- [ ] **Risk Metrics**:
  - `calculate_volatility` - Portfolio volatility
  - `calculate_max_drawdown` - Maximum loss from peak
  - `calculate_var` - Value at Risk estimation
- [ ] **Trade Analytics**:
  - `analyze_trade_quality` - Win rate, profit factor
  - `calculate_execution_costs` - Slippage and commissions
  - `generate_trade_report` - Detailed trade breakdown

### Testing (`test/test_*.ml`)
- [ ] **Strategy Tests**:
  - Built-in strategy correctness
  - Custom strategy framework
  - Signal generation accuracy
- [ ] **Simulation Engine Tests**:
  - Time advancement logic
  - Event processing correctness
  - State management integrity
- [ ] **Integration Tests**:
  - End-to-end backtesting workflow
  - Historical data integration
  - Performance analytics accuracy
- [ ] **Performance Tests**:
  - Large dataset simulation speed
  - Memory usage optimization
  - Concurrent simulation support

### Build Configuration
- [ ] `lib/dune` - Library configuration
- [ ] `test/dune` - Test configuration
- [ ] `bin/dune` - CLI tools for running simulations

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