# Dependency Rules

This document is the canonical source of truth for architectural dependency
boundaries in this codebase. It is read by the `health-scanner` (T3-A), used
as the authoritative reference for `qc-structural` reviews, and drives the
rule-promotion workflow described in T3-F of the harness engineering plan.

---

## Rule lifecycle

| State | Enforcement | Notes |
|---|---|---|
| `proposed` | None | Under discussion; not yet checked mechanically |
| `monitored` | Soft — health-scanner reports violations | Agent surfaces, human decides whether to promote |
| `enforced` | Hard — fails `dune runtest` | Lives in `trading/devtools/checks/`; gate blocks merge |

Every rule below lists its current state and, if enforced, the check that
implements it. Exceptions are maintained in
`trading/devtools/checks/linter_exceptions.conf`.

---

## Known rules

### R1 — `analysis/` must not import from `trading/trading/`

| Field | Value |
|---|---|
| State | `enforced` |
| Check | `trading/devtools/checks/arch_layer_test.sh` |
| Scope | All `dune` files under `trading/analysis/` |

The analysis layer (`analysis/`) contains pure analysis logic — stage
classification, screening, macro/sector analysis, indicators. It must not
depend on the trading execution layer (`trading/trading/` — orders, portfolio,
engine, simulation, strategy). This keeps analysis modules independently
testable and reusable outside any execution context.

**Allowed exception:** `analysis/weinstein/portfolio_risk/` may import
`trading.portfolio`. This module is an explicit bridge: it translates
Weinstein-computed risk parameters (position sizing, exposure limits) into
portfolio-compatible data structures. It is the only sanctioned crossing of
the analysis/trading boundary and is listed in `linter_exceptions.conf`.

---

### R2 — `trading/trading/weinstein/` must not import from `analysis/weinstein/`

| Field | Value |
|---|---|
| State | `monitored` |
| Check | None yet (health-scanner scans for violations) |

The trading-side Weinstein modules (`trading/trading/weinstein/stops/` and
`trading/trading/weinstein/trading_state/`) implement the trailing stop state
machine and persist trading state. They share types with the analysis layer
(`weinstein.types`) but must not import analysis modules (stage classifiers,
screener, macro, etc.). The direction of data flow is one-way: analysis
produces signals, trading consumes them via typed values, never by calling
back into the analysis layer.

Violation would create a circular dependency and couple the stop engine to
analysis implementation details.

---

### R3 — `trading/trading/simulation/` must not be imported by the live execution path

| Field | Value |
|---|---|
| State | `monitored` |
| Check | None yet (health-scanner scans for violations) |

The simulator (`trading.simulation`) wraps the full analysis-to-order pipeline
for backtesting. It must not be a dependency of any live execution module —
its simulated fill model, synthetic portfolio management, and performance metric
computation are purely backtesting concerns. Live code that depends on
simulation internals would make it impossible to audit which logic runs in
production.

---

### R4 — `analysis/weinstein/types/` must not import from other `analysis/weinstein/` modules

| Field | Value |
|---|---|
| State | `enforced` (by dune structure — the library has no weinstein deps) |
| Check | Implicit: `weinstein.types` dune file lists only `core` as a dependency |

`weinstein.types` defines the shared data types (stage variants, analysis
result records, config, etc.) used by all other Weinstein analysis modules.
If it were to import from sibling analysis modules it would create cycles and
prevent the types module from being a stable foundation. This is enforced
structurally today — the `weinstein.types` dune file lists only `core`. Any
addition of a `weinstein.*` library to that dune file should be treated as a
violation.

---

### R5 — `analysis/` must receive market data only via the `DATA_SOURCE` interface

| Field | Value |
|---|---|
| State | `proposed` |
| Check | None yet |

Analysis modules should not call concrete data-layer implementations directly
(e.g., constructing an EODHD client inline, or reading from CSV storage
directly). All market data should flow in through the `DATA_SOURCE` interface
(`analysis/weinstein/data_source/`). This is the seam that makes live and
historical modes identical from the analysis layer's perspective — if analysis
code bypasses the interface and calls a concrete implementation, that seam
breaks and the same pipeline can no longer be used for both live and backtest.

Currently not mechanically enforced because the interface boundary is recent.
Promote to `monitored` once all analysis modules have been audited.

---

### R6 — `trading/trading/base/` must not import from other `trading/trading/` modules

| Field | Value |
|---|---|
| State | `enforced` (by dune structure) |
| Check | Implicit: `trading.base` dune file lists only `core` |

`trading.base` defines primitive trading types (`symbol`, `price`, `quantity`,
`side`, `order_type`, `trade`). These are the foundation of the entire trading
layer. Importing from orders, portfolio, engine, or strategy would create
cycles. Enforced structurally today; any `trading.*` addition to the
`trading.base` dune file should be rejected.

---

## Dependency graph summary

The allowed import directions (arrows mean "may import"):

```
infrastructure (core, status, types)
        ↓
analysis/data/types  (types: Daily_price, Cadence)
        ↓
analysis/technical/indicators  (sma, ema, relative_strength, ...)
        ↓
analysis/weinstein/types  (stage variants, analysis result records)
        ↓
analysis/weinstein/  (stage, rs, volume, resistance, macro, sector, screener, stock_analysis)
        ↓
analysis/weinstein/portfolio_risk  [EXCEPTION: also imports trading.portfolio]
        ↓
trading/trading/base  (symbol, price, quantity, side, order_type)
        ↓
trading/trading/orders / trading/trading/portfolio / trading/trading/engine
        ↓
trading/trading/strategy
        ↓
trading/trading/simulation
        ↓
trading/trading/weinstein/stops  [imports weinstein.types, trading.base — not analysis modules]
        ↓
trading/trading/weinstein/trading_state  [imports trading.portfolio, trading.strategy — not analysis modules]
```

The `analysis/weinstein/portfolio_risk` exception is the only sanctioned
crossing of the analysis/trading boundary. All other traffic must flow top-down
through this graph.

---

## Adding or changing rules

1. Identify the boundary and write it as a new rule entry above (state:
   `proposed`).
2. Once agreed, advance to `monitored` — the health-scanner's deep scan will
   flag violations from that point forward.
3. When the health-scanner reports zero violations for two consecutive deep
   scans, open a PR promoting the rule to `enforced`: add the corresponding
   check script to `trading/devtools/checks/` and add it to the dune test
   target. Add an entry to `linter_exceptions.conf` for any accepted
   exceptions.
4. Remove the rule if it becomes vacuously true (module renamed or deleted) or
   the design changes. Document the removal reason inline as a comment before
   deleting.
