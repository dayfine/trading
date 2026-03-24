# Existing Codebase Assessment + Integration Plan

## Summary

The `dayfine/trading` repo is a **solid foundation** to build on. It has ~18,600 lines of OCaml across 34 test files, with well-designed modules for exactly the infrastructure we'd otherwise need to build from scratch. The architecture aligns closely with our design, and the integration points are clean.

**Recommendation: build on top of this, not from scratch.**

---

## What Exists

### Infrastructure (ready to use)

| Module | What it does | Lines | Tests | Maturity |
|--------|-------------|-------|-------|----------|
| `base/types` | Symbol, price, quantity, side, order_type, trade | ~100 | Yes | Solid |
| `base/status` | Result types, error handling, combinators | ~200 | Yes | Solid |
| `base/matchers` | Test assertion library | ~300 | Yes | Solid |
| `orders/` | Order creation, validation, lifecycle, CRUD | ~1600 | 3 test files | Solid |
| `portfolio/` | Position tracking, cash, P&L, trade application | ~2000 | 2 test files | Solid |
| `engine/` | Simulated broker, OHLC price path, order execution | ~2000 | 3 test files | Solid |
| `simulation/` | Daily sim loop, step/run, strategy integration | ~3000 | 8 test files | Active development |
| `strategy/` | STRATEGY interface, position state machine, 2 strategies | ~2500 | 6 test files | Active development |

### Analysis (partially reusable)

| Module | What it does | Reusable? |
|--------|-------------|-----------|
| `data/sources/eodhd/` | EODHD HTTP client (historical prices, symbols, bulk) | **Yes** — extend with weekly period param + A-D data |
| `data/storage/csv/` | CSV read/write with metadata | **Yes** — our cache layer |
| `data/types/` | `Daily_price.t`, `Cadence.t` | **Yes** — extend for weekly bars |
| `data/pipelines/` | Fetch + save prices pipeline | **Yes** — template for our data fetch |
| `technical/indicators/ema/` | EMA calculation | **Partially** — need SMA + weighted MA too |
| `technical/indicators/time_period/` | Daily → weekly conversion | **Yes** — already handles partial weeks |
| `technical/trend/` | Linear regression, segmentation | **Possibly** — for trend slope analysis |
| `scripts/above_30w_ema/` | Stocks above 30w EMA screen | **Starting point** — primitive Weinstein screen |

### Key Design Patterns Already Established

- Variant types for domain modeling (`side`, `order_type`, `order_status`, `position_state`)
- `.mli` interfaces on everything
- Result types for error handling (`Status.status_or`)
- Test-driven development with custom matchers
- Core library throughout (not stdlib)
- Async for I/O (EODHD client uses `Async`, not `Lwt`)
- Position as an explicit state machine (`Entering → Holding → Exiting → Closed`)
- Strategy as a module signature (`STRATEGY`) with `on_market_close`

---

## What Aligns With Our Design

### The `STRATEGY` module type IS our integration point

The existing strategy interface is exactly what a Weinstein strategy needs to implement:

```ocaml
module type STRATEGY = sig
  val on_market_close :
    get_price:get_price_fn ->
    get_indicator:get_indicator_fn ->
    positions:Position.t String.Map.t ->
    output Status.status_or

  val name : string
end
```

A Weinstein strategy module would:
- Use `get_price` to fetch weekly bars for stocks and indices
- Use `get_indicator` to get MAs, RS values, volume ratios
- Look at `positions` to know what's currently held
- Return `transitions` — CreateEntering for new buys, TriggerExit for stop hits, UpdateRiskParams for stop adjustments

### The Position state machine maps to Weinstein stops

The existing `Position.t` already has:
- `Entering` with target price → our GTC buy-stop orders
- `Holding` with `risk_params` (stop_loss_price, take_profit_price) → our trailing stops
- `Exiting` → our stop-hit exits
- `UpdateRiskParams` transition → our stop ratcheting

We'd extend `risk_params` or add Weinstein-specific metadata, but the state machine is the right shape.

### The Simulator already runs the pipeline we designed

```
Simulator.step:
  1. Update market data
  2. Process pending orders (Engine)
  3. Apply trades to portfolio
  4. Call strategy (on_market_close)
  5. Apply strategy transitions (create/exit positions)
  6. Generate new orders from transitions
```

This IS our "same pipeline, different data source" abstraction. The simulator steps daily; we'd add a weekly mode, but the loop structure is correct.

---

## What's Missing (What We Build)

### 1. Weinstein Analysis Layer (NEW)

This is the core new work — the domain-specific analysis that doesn't exist yet:

```
analysis/weinstein/
├── stage/           # Stage classifier (the state machine)
│   ├── stage.mli    # Stage type + classify function
│   └── stage.ml
├── macro/           # Market regime analyzer
│   ├── macro.mli    # macro_state type + analyze function
│   └── macro.ml
├── sector/          # Sector health analyzer
│   ├── sector.mli
│   └── sector.ml
├── screener/        # Cascade filter + scoring
│   ├── screener.mli
│   └── screener.ml
├── relative_strength/
│   ├── rs.mli
│   └── rs.ml
├── resistance/      # Overhead resistance mapping
│   ├── resistance.mli
│   └── resistance.ml
├── volume/          # Volume confirmation analysis
│   ├── volume.mli
│   └── volume.ml
└── stops/           # Weinstein-specific trailing stop rules
    ├── weinstein_stops.mli
    └── weinstein_stops.ml
```

### 2. Weinstein Strategy (NEW)

A strategy module implementing the `STRATEGY` interface:

```
trading/strategy/lib/
├── weinstein_strategy.mli
└── weinstein_strategy.ml
```

This calls into the analysis layer and translates results into `Position.transition` values the simulator understands.

### 3. Indicators (EXTEND)

The existing EMA is a start, but we need:
- **SMA** (simple moving average)
- **Weighted MA** (Mansfield-style)
- **Advance-decline line** (cumulative breadth)
- **Momentum index** (200-day MA of A-D net)
- **New highs minus new lows**

These fit naturally into:
```
analysis/technical/indicators/
├── ema/          # existing
├── sma/          # NEW
├── weighted_ma/  # NEW
├── breadth/      # NEW (A-D line, momentum index, NH-NL)
└── types/        # existing
```

### 4. EODHD Client Extensions (EXTEND)

The existing client fetches daily prices and symbols. We need:
- Weekly period parameter (`period=w`)
- Index data (DJI, SPX, global indices)
- Fundamentals (sector/industry metadata)
- Advance-decline data (if available via EODHD, otherwise compute from constituent data)

### 5. Weekly Simulation Mode (EXTEND)

The simulator currently steps daily. We need a weekly mode where:
- Strategy runs once per week (Friday close)
- Orders execute the following week against daily price paths
- This matches Weinstein's "review weekend, place orders Monday" cadence

### 6. Config System (NEW)

The existing code uses per-strategy configs. We need a unified config that governs all Weinstein parameters:

```
analysis/weinstein/config/
├── config.mli    # All tunable parameters
└── config.ml
```

### 7. Reporter (NEW)

Weekly report generation, alert dispatch:

```
analysis/weinstein/reporter/
├── reporter.mli
└── reporter.ml
```

---

## What We DON'T Need to Build

- Order management → `trading/orders/` ✓
- Portfolio tracking → `trading/portfolio/` ✓
- Trade execution → `trading/engine/` ✓
- Simulation loop → `trading/simulation/` ✓
- Strategy interface → `trading/strategy/` ✓
- Position state machine → `strategy/lib/position.ml` ✓
- EODHD HTTP client → `data/sources/eodhd/` ✓
- Data storage → `data/storage/csv/` ✓
- Daily→weekly conversion → `indicators/time_period/` ✓
- EMA calculation → `indicators/ema/` ✓
- Trend regression → `technical/trend/` ✓
- Test matchers → `base/matchers/` ✓

---

## Technical Notes

### Async vs Lwt

The existing codebase uses **Jane Street's Async**, not Lwt. Our earlier design doc assumed Lwt (cohttp-lwt-unix). Since the repo already has Async throughout, we should use Async consistently. This means `cohttp-async` if we need additional HTTP calls.

### Core vs Stdlib

The repo uses `Core` extensively. All new code should follow suit.

### Module Organization

The repo has a clear two-level structure:
- `trading/trading/` — trading system (orders, portfolio, engine, simulation, strategy)
- `trading/analysis/` — analysis framework (data, technical, scripts)

Our new Weinstein code fits cleanly as `trading/analysis/weinstein/` for the analysis layer, and `trading/trading/strategy/lib/weinstein_strategy.ml` for the strategy implementation.

---

## Revised Build Plan

Given the existing codebase, the phases shift — we skip infrastructure and go straight to domain logic:

| Phase | What | Builds on |
|-------|------|-----------|
| **P1** | SMA + weighted MA indicators | Existing EMA pattern |
| **P2** | Stage classifier | New indicators + existing trend module |
| **P3** | Relative strength calculator | Existing indicator types |
| **P4** | Volume confirmation + resistance mapper | Existing data types |
| **P5** | Macro analyzer (DJI stage, A-D, MI) | P2 stage classifier + new breadth indicators |
| **P6** | Sector analyzer | P2 + P3 |
| **P7** | Screener (cascade filter + scoring) | P5 + P6 + P2-P4 |
| **P8** | Weinstein trailing stop rules | Extend existing Position risk_params |
| **P9** | Weinstein strategy module | Implements existing STRATEGY interface, uses P2-P8 |
| **P10** | Weekly simulation mode | Extend existing simulator |
| **P11** | Config system + reporter | New |
| **P12** | EODHD extensions (weekly, indices, fundamentals) | Extend existing client |

P1 is a ~200 line module. P2 is the first substantial new work. By P9 we have a working strategy that plugs into the existing simulator for backtesting. P10-P12 are polish and integration.

---

## Next Steps

1. **Agree on this plan** — does building on the existing repo make sense to you?
2. **Component design doc for Stage Classifier** (P2) — this is the heart of Weinstein and the first substantial new module. Worth a detailed design before coding.
3. **Start P1** — SMA + weighted MA are small, self-contained, and immediately testable. Good warm-up that establishes patterns for new code in the existing repo.
