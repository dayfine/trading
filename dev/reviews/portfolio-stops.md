# QC Review: portfolio-stops / order_gen

## Review date: 2026-04-06
## Branch: feat/portfolio-stops-order-gen
## Commit: 1a98016e (Add arch_layer exception; QC APPROVED)

Note: All prior code (stops, portfolio_risk, trading_state) is already on main.
This review covers `analysis/weinstein/order_gen/` only.

---

## Stage 1: Structural QC

### Hard Gates

| Check | Result |
|-------|--------|
| dune build | PASS |
| dune runtest (full) | PASS — 9/9 order_gen tests pass, all existing tests pass |
| arch_layer_test.sh | PASS — exception registered in linter_exceptions.conf |
| linter_mli_coverage.sh | PASS |
| linter_magic_numbers.sh | PASS |
| fn_length_linter | PASS — no functions exceed 50 lines |

### Structural Checklist

**Interface completeness**
- [x] `.mli` exists with doc comments on all public types and functions
- [x] `suggested_order` type has `[@@deriving show, eq]`
- [x] All three functions have `@param` and `@return` docs
- [x] Module-level doc explains design intent and relationship to `order_generator.ml`

**Function signatures**
- [x] Match the design spec in `eng-design-3-portfolio-stops.md`
- [x] One intentional deviation: `rationale` is `string list` not `string` — preserves screener rationale list intact (better than design spec)
- [x] Pure functions — no state, no side effects

**Code quality**
- [x] `_exit_side` and `_holding_quantity` helpers are small (< 5 lines each)
- [x] `from_candidates` filters on both sizing (shares = 0) and limits (check_limits)
- [x] Pattern match on `stop_event` uses `| _ -> None` catch-all for forward compatibility
- [x] No magic numbers in lib/ — all thresholds delegated to `Portfolio_risk.config`
- [x] `StopLimit (entry, entry)` for entries — correct buy-stop at breakout price

**Test coverage**
- [x] 9 tests: empty input, max-position limit exclusion, StopLimit entry, Stop_raised adjustment, Stop_hit ignored in adjustments, Stop_hit market exit, short position Buy-to-cover, Stop_raised ignored in exits, unknown ticker graceful no-op
- [x] `make_holding_position` helper exercises full Position state machine (CreateEntering -> EntryFill -> EntryComplete)
- [x] `elements_are` matcher used for list structure validation
- [x] `is_some_and`/`is_none` used for Option assertions

**Architecture**
- [x] Does NOT modify existing Portfolio, Orders, Position, or Engine modules
- [x] Arch exception added to `linter_exceptions.conf` with reason and `review_at` note
- [x] Placed alongside (not replacing) `trading/simulation/lib/order_generator.ml`

### Structural Decision: APPROVED

---

## Stage 2: Behavioral QC

### Domain correctness

**Entry order type**
- [x] `StopLimit (entry, entry)` for new entries: Correct Weinstein mechanic — buy-stop triggers when price breaks above resistance level
- [x] Long-only entries (`side = Buy`): Correct — screener produces Stage 2 buy candidates

**Stop order semantics**
- [x] `Stop_raised` -> `Stop new_level` order with exit side: Sell stop for long, Buy stop for short — correct Weinstein trailing stop replacement
- [x] `Stop_hit` -> `Market` exit: Correct — Weinstein advises immediate exit at market when stop is breached
- [x] Short position exit -> `Buy` side: Correct cover direction

**Portfolio risk integration**
- [x] `check_limits` gates entry generation — enforces max_positions, exposure limits, sector concentration
- [x] `compute_position_size` uses `entry_price` and `stop_price` for fixed-risk sizing — correct Weinstein sizing formula
- [x] `sizing.shares = 0` edge case handled

**Separation of concerns**
- [x] `from_candidates` handles entries only
- [x] `from_stop_adjustments` handles stop raises only
- [x] `from_exits` handles stop hits only
- [x] Each function ignores irrelevant events via `| _ -> None`

### Behavioral Decision: APPROVED

---

## Combined QC Result: APPROVED

Ready to merge `feat/portfolio-stops-order-gen` to main. The arch exception in `linter_exceptions.conf` is included in the commit.
