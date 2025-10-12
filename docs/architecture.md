# Trading System Architecture

## Module Dependencies & Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     SIMULATION MODULE                       │
│  ┌─────────────────────────────────────────────────────────┤
│  │ • Strategy algorithms generate trading signals           │
│  │ • Backtesting framework orchestrates the entire flow    │
│  │ • Performance analytics and reporting                   │
│  └─────────────────────┬───────────────────────────────────┘
│                        │ creates & submits orders
│                        ▼
├─────────────────────────────────────────────────────────────┤
│                      ORDERS MODULE                          │
│  ┌─────────────────────────────────────────────────────────┤
│  │ • Order creation, validation, and lifecycle management  │ ◀─┐
│  │ • CRUD operations for order storage                     │   │
│  │ • Order filtering and status tracking                   │   │
│  │ • Central hub for all order-related data               │   │
│  └─────────────────────┬───────────────────────────────────┘   │
│                        │ sends orders for execution            │
│                        ▼                                       │
├─────────────────────────────────────────────────────────────┤   │
│                      ENGINE MODULE                          │   │
│  ┌─────────────────────────────────────────────────────────┤   │
│  │ • Receives orders from orders module                    │   │
│  │ • Executes orders (market simulation)                   │   │
│  │ • Updates order status and creates execution reports    │───┘
│  │ • Validates orders against portfolio state              │
│  └─────────────────────┬───────────────────────────────────┘
│                        │ portfolio queries for filled orders
│                        ▼
├─────────────────────────────────────────────────────────────┤
│                    PORTFOLIO MODULE                         │
│  ┌─────────────────────────────────────────────────────────┤
│  │ • Reads execution results from orders module            │
│  │ • Updates positions and cash balances                   │
│  │ • Calculates P&L and portfolio valuation               │
│  │ • Provides portfolio state for validation               │
│  └─────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────┘
```

## Detailed Data Flow

### 1. Simulation → Engine
**What**: Order submission for execution
```ocaml
(* Simulation generates trading signals and submits orders *)
let orders = strategy_generate_signals market_data portfolio_state in
let execution_results = Engine.execute_orders orders market_data in
```

**Data Flow**:
- Strategy generates `order list` based on market data and portfolio state
- Engine receives orders and processes them against simulated market
- Engine returns `execution_report list` with trade details

### 2. Engine → Orders (Trade Execution Updates)
**What**: Engine updates order status and creates trade records
```ocaml
(* Engine updates orders with execution results *)
let execution_reports = Engine.execute_orders orders market_data in
let updated_orders = Orders.update_orders_from_execution orders execution_reports in
```

**Data Flow**:
- Engine executes orders and generates execution reports
- Engine updates order status (Filled, PartiallyFilled, etc.) in Orders module
- Engine may create separate trade records for portfolio consumption

### 3. Orders → Portfolio (Trade Application)
**What**: Portfolio receives trade information to update positions
```ocaml
(* Portfolio gets trade info from executed orders *)
let filled_orders = Orders.get_filled_orders order_manager in
let trades = Orders.extract_trades_from_orders filled_orders in
let updated_portfolio = Portfolio.apply_trades portfolio trades in
```

**Data Flow**:
- Portfolio queries Orders module for executed/filled orders
- Portfolio extracts trade information from order execution results
- Portfolio updates positions and cash based on completed trades

### 4. No Circular Dependencies
**Clean Separation**:
- Engine validates against Portfolio state (passed as parameter)
- Engine updates Orders module with execution results
- Portfolio reads execution results from Orders module
- No direct Engine ↔ Portfolio dependency

## Key Interfaces

### Engine Interface (Receives from Simulation)
```ocaml
val execute_orders : order list -> market_data -> execution_report list
val get_portfolio_value : portfolio -> market_data -> float
val validate_orders : order list -> portfolio -> validation_result list
```

### Portfolio Interface (Receives from Orders)
```ocaml
val apply_trades_from_orders : portfolio -> order list -> portfolio
val get_cash_balance : portfolio -> float
val get_position : portfolio -> symbol -> position option
val check_buying_power : portfolio -> order -> bool
```

### Orders Interface (Central Hub)
```ocaml
(* Used by Simulation *)
val create_orders : order_params list -> order list status_or
val submit_orders : order_manager -> order list -> status list

(* Updated by Engine *)
val update_order_status : order_manager -> order_id -> order_status -> unit
val get_execution_results : order_manager -> execution_report list

(* Used by Portfolio *)
val get_filled_orders : order_manager -> order list
val extract_trade_info : order -> trade_info option
```

## Module Responsibilities

### 📊 **Simulation Module** (Orchestrator)
- **Primary Role**: Strategy execution and backtesting framework
- **Uses**: Engine (for order execution), Portfolio (for state), Orders (for creation)
- **Responsibilities**:
  - Generate trading signals from strategies
  - Orchestrate the trading loop (signal → order → execution → portfolio update)
  - Collect performance metrics and analytics
  - Manage simulation time and market data

### ⚙️ **Engine Module** (Execution Layer)
- **Primary Role**: Order execution and market simulation
- **Uses**: Portfolio (for validation), Orders (for status updates)
- **Responsibilities**:
  - Execute orders against simulated market conditions
  - Generate realistic trade fills and execution reports
  - Validate orders against portfolio constraints
  - Model market impact and execution costs

### 💰 **Portfolio Module** (State Management)
- **Primary Role**: Position and cash tracking
- **Uses**: Orders (for validation context)
- **Responsibilities**:
  - Track positions, cash balances, and P&L
  - Apply trade execution results to update state
  - Provide portfolio valuation and risk metrics
  - Support order validation with current holdings

### 📋 **Orders Module** (Data Layer)
- **Primary Role**: Order lifecycle management
- **Uses**: Base types only
- **Responsibilities**:
  - Create, validate, and store orders
  - Track order status through lifecycle
  - Provide order filtering and querying
  - Maintain order history and metadata

## Benefits of This Architecture

1. **Clear Separation of Concerns**: Each module has a distinct responsibility
2. **Unidirectional Data Flow**: Prevents circular dependencies and makes testing easier
3. **Composability**: Modules can be tested independently
4. **Flexibility**: Different strategies and execution methods can be plugged in
5. **Maintainability**: Changes in one module have minimal impact on others