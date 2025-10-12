# Portfolio Module

## Overview
Portfolio management system for tracking positions, cash balances, and P&L calculations.

## Current Status
🚧 **SCAFFOLDED** - Only directory structure exists

## TODO

### Core Types (`lib/types.mli` & `lib/types.ml`)
- [ ] Define `portfolio_position` type with:
  - Symbol, quantity, average cost basis
  - Market value tracking
  - Unrealized P&L calculation
- [ ] Define `portfolio` type with:
  - Unique portfolio ID
  - Cash balance
  - Position holdings (symbol -> position mapping)
  - Realized P&L tracking
  - Creation/update timestamps
- [ ] Implement position manipulation functions:
  - `update_position` - Add/remove shares, update cost basis
  - `get_position` - Retrieve position for symbol
  - `list_positions` - Get all positions
- [ ] Implement cash management:
  - `update_cash` - Modify cash balance
  - `get_cash_balance` - Current cash amount
- [ ] Implement portfolio valuation:
  - `calculate_portfolio_value` - Total portfolio worth
  - `calculate_unrealized_pnl` - Unrealized gains/losses

### Portfolio Manager (`lib/manager.mli` & `lib/manager.ml`)
- [ ] Portfolio CRUD operations:
  - `create_portfolio` - Initialize new portfolio
  - `get_portfolio` - Retrieve portfolio by ID
  - `list_portfolios` - Get all portfolios
- [ ] Trade execution integration:
  - `execute_trade` - Update portfolio from order execution
  - `settle_trade` - Handle trade settlement
- [ ] Portfolio operations:
  - `transfer_cash` - Add/remove cash
  - `transfer_positions` - Move positions between portfolios
- [ ] Reporting functions:
  - `portfolio_summary` - Key metrics and balances
  - `position_report` - Detailed position breakdown

### Testing (`test/test_*.ml`)
- [ ] **Core functionality tests**:
  - Portfolio creation and initialization
  - Position updates (buy/sell scenarios)
  - Cash balance modifications
  - P&L calculations accuracy
- [ ] **Edge case tests**:
  - Zero quantity positions
  - Negative cash balances
  - Large position sizes
  - Concurrent modifications
- [ ] **Integration tests**:
  - Portfolio + Order execution workflow
  - Multi-symbol portfolio operations
  - Portfolio valuation with market data

### Build Configuration
- [ ] `lib/dune` - Library configuration with dependencies
- [ ] `test/dune` - Test configuration

## Dependencies
- `trading.base` - Core types (symbol, price, quantity, position)
- `trading.orders` - Integration with order execution
- `core` - Standard library
- `ounit2` - Testing framework

## Key Design Decisions
1. **Position Tracking**: Average cost basis method for position costing
2. **Cash Management**: Separate cash balance from position values
3. **P&L Calculation**: Both realized (from closed positions) and unrealized (from open positions)
4. **Data Storage**: Hashtable for efficient symbol-based position lookups
5. **Immutability**: Functional updates return new portfolio states

## Integration Points & Data Flow

**Portfolio is the STATE MANAGER** - it tracks positions and provides validation context:

### Portfolio ← Orders (receives trade execution results)
```ocaml
(* Apply executed trades to update portfolio *)
val apply_trades_from_orders : portfolio -> order list -> portfolio
val extract_trade_from_order : order -> trade_info option

(* Example: Portfolio queries orders for filled orders *)
let filled_orders = Orders.get_filled_orders order_manager in
let updated_portfolio = Portfolio.apply_trades_from_orders portfolio filled_orders
```

### Portfolio → Engine (provides validation context - passed as parameter)
```ocaml
(* Engine receives portfolio state for validation *)
val get_cash_balance : portfolio -> float
val get_position : portfolio -> symbol -> portfolio_position option
val check_buying_power : portfolio -> order -> bool

(* Example: Engine validates against portfolio state *)
let can_buy = Portfolio.check_buying_power portfolio buy_order in
(* Portfolio state passed to engine, not stored *)
```

### Portfolio → Simulation (provides performance tracking)
```ocaml
(* Simulation tracks portfolio value over time *)
val calculate_portfolio_value : portfolio -> market_data -> float
val get_unrealized_pnl : portfolio -> market_data -> float
val get_total_return : portfolio -> float
```

**Dependencies**:
- **Orders Module**: Read trade execution results from filled orders
- **Simulation Module**: Provide portfolio state for strategy decisions

## Future Enhancements
- Multiple account support
- Position sizing algorithms
- Risk management constraints
- Portfolio rebalancing utilities
- Performance attribution analysis