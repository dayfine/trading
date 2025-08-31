# Trading System

This directory contains the core trading system components organized as separate dune projects.

## Structure

### base
Core data types and utilities used throughout the trading system:
- Symbol, Price, Quantity
- Side (Buy/Sell)
- Order types (Market, Limit, Stop)
- Money and Currency
- Position

### engine
Trading engine for executing trades:
- Order management
- Execution status tracking
- Order lifecycle management

### orders
Order management and validation:
- Order request/response types
- Order validation
- Order creation utilities
- Order formatting

### portfolio
Portfolio and position management:
- Position tracking
- Portfolio value calculation
- P&L calculations
- Position updates

### simulation
Backtesting and simulation framework:
- Market data handling
- Trade execution simulation
- Commission and slippage modeling
- Backtest results

## Building

To build all components:

```bash
cd trading/trading
dune build
```

To build a specific component:

```bash
cd trading/trading/base
dune build
```

## Running

To run the base demo:

```bash
cd trading/trading/base
dune exec main
```

## Testing

To run tests for a component:

```bash
cd trading/trading/base
dune runtest
```

## Dependencies

Each component depends on the `base` library for common types. The `simulation` component depends on all other components to provide a complete backtesting framework.

## Usage Example

```ocaml
open Base
open Orders
open Portfolio
open Simulation

(* Create a portfolio *)
let portfolio = Portfolio.create { amount = 10000.0; currency = USD }

(* Create an order *)
let order = Orders.create_market_order "AAPL" Buy 100

(* Run a simulation *)
let config = {
  initial_cash = { amount = 10000.0; currency = USD };
  commission_rate = 0.1;
  slippage = 0.05;
}
```
