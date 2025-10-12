# Trading Engine Module

## Overview
Core trading execution engine responsible for order processing, market simulation, and trade generation.

## Current Status
🚧 **SCAFFOLDED** - Only directory structure exists

## TODO

### Core Types (`lib/types.mli` & `lib/types.ml`)
- [ ] Define `trade` type:
  - Trade ID, symbol, side, quantity, price
  - Execution timestamp
  - Order ID reference
  - Trade fees/commissions
- [ ] Define `market_data` type:
  - Symbol, bid/ask prices, volumes
  - Last trade price and size
  - Market depth (optional)
- [ ] Define `execution_report` type:
  - Order execution status
  - Fill details (partial/complete)
  - Remaining quantity
  - Average fill price
- [ ] Define engine configuration:
  - Market hours, trading rules
  - Commission structure
  - Slippage modeling parameters

### Order Execution Engine (`lib/execution.mli` & `lib/execution.ml`)
- [ ] **Market Order Execution**:
  - `execute_market_order` - Immediate execution at market price
  - Price slippage simulation
  - Partial fill handling for large orders
- [ ] **Limit Order Execution**:
  - `execute_limit_order` - Execute when price condition met
  - Order book priority simulation
  - Price improvement opportunities
- [ ] **Stop Order Execution**:
  - `execute_stop_order` - Trigger conversion to market order
  - Stop price monitoring
  - Slippage on stop execution
- [ ] **Order Validation**:
  - `validate_order` - Check order parameters
  - Portfolio balance verification
  - Position size limits

### Market Simulation (`lib/market.mli` & `lib/market.ml`)
- [ ] **Price Generation**:
  - `simulate_market_price` - Generate realistic bid/ask spreads
  - `apply_market_impact` - Model price impact of large orders
  - Volatility and trend simulation
- [ ] **Liquidity Modeling**:
  - `calculate_available_liquidity` - Market depth simulation
  - `estimate_execution_price` - Price impact estimation
  - Time-of-day liquidity variations
- [ ] **Market Data Management**:
  - `update_market_data` - Real-time price updates
  - `get_current_prices` - Latest market prices
  - Historical price storage and retrieval

### Trading Engine Core (`lib/engine.mli` & `lib/engine.ml`)
- [ ] **Engine State Management**:
  - `create_engine` - Initialize trading engine
  - `start_engine` / `stop_engine` - Engine lifecycle
  - Market session management
- [ ] **Order Processing Pipeline**:
  - `submit_order_to_engine` - Receive orders from order manager
  - `process_pending_orders` - Execute ready orders
  - `generate_execution_reports` - Send results back
- [ ] **Portfolio Integration**:
  - `update_portfolio_from_trades` - Apply executed trades
  - `validate_portfolio_constraints` - Risk checks
  - Position limit enforcement

### Testing (`test/test_*.ml`)
- [ ] **Execution Logic Tests**:
  - Market order immediate execution
  - Limit order conditional execution
  - Stop order trigger mechanisms
  - Partial fill scenarios
- [ ] **Market Simulation Tests**:
  - Price generation algorithms
  - Liquidity modeling accuracy
  - Market impact calculations
- [ ] **Integration Tests**:
  - End-to-end order processing
  - Portfolio update workflows
  - Multi-order execution scenarios
- [ ] **Performance Tests**:
  - High-frequency order processing
  - Large order execution
  - Concurrent order handling

### Build Configuration
- [ ] `lib/dune` - Library configuration
- [ ] `test/dune` - Test configuration
- [ ] `bin/dune` - Executable configuration (if needed)

## Dependencies
- `trading.base` - Core types
- `trading.orders` - Order management integration
- `trading.portfolio` - Portfolio updates
- `core` - Standard library
- `ounit2` - Testing framework

## Key Design Decisions
1. **Execution Strategy**: Separate execution logic by order type
2. **Market Simulation**: Realistic but deterministic price generation
3. **Portfolio Integration**: Direct portfolio updates from trade execution
4. **Performance**: Efficient order processing for high-frequency scenarios
5. **Modularity**: Pluggable market data sources and execution algorithms

## Integration Points & Data Flow

**Engine is the EXECUTION LAYER** - it processes orders and generates trades:

### Engine ← Simulation (receives orders)
```ocaml
(* Receive orders from simulation strategies *)
val execute_orders : order list -> market_data -> execution_report list
```

### Engine → Portfolio (sends execution results)
```ocaml
(* Generate trades from order execution *)
let trades = [
  { id = "trade_1"; symbol = "AAPL"; side = Buy; quantity = 100.0; price = 150.0; ... }
] in
let updated_portfolio = Portfolio.apply_trades portfolio trades
```

### Engine ↔ Portfolio (validation)
```ocaml
(* Validate orders against portfolio state *)
val validate_order_against_portfolio : order -> portfolio -> bool
val check_sufficient_cash : order -> portfolio -> bool
```

**Dependencies**:
- **Orders Module**: Receive submitted orders for execution and update order status
- **Portfolio Module**: Validate orders against current holdings and send execution results
- **Simulation Module**: Provide execution engine for backtesting

## Future Enhancements
- Real market data integration
- Advanced order types (iceberg, TWAP, VWAP)
- Risk management integration
- Execution analytics and reporting
- Multi-venue execution routing