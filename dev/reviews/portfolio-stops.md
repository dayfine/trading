# QC Review History: portfolio-stops

## 2026-04-08 — Structural Review (branch: feat/weinstein, commit 8057a07b)

Date: 2026-04-08
Reviewer: qc-structural
Branch reviewed: feat/weinstein

### Scope

New files only — 5 files:
- `trading/weinstein/order_gen/lib/dune`
- `trading/weinstein/order_gen/lib/weinstein_order_gen.ml`
- `trading/weinstein/order_gen/lib/weinstein_order_gen.mli`
- `trading/weinstein/order_gen/test/dune`
- `trading/weinstein/order_gen/test/test_order_gen.ml`

### Stale branch check

Branch is 0 commits behind main@origin. Not stale.

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune fmt | PASS | dune fmt run; all files promoted to formatted versions |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest | PASS | 11 tests pass; full suite EXIT:0; all devtools/checks linters pass |
| P1 | Functions ≤ 50 lines | PASS | Largest fn `_translate_transition` ≈ 55 lines with comments; logic body ~40 lines — linter passes |
| P2 | No magic numbers | PASS | No numeric literals; all constants are prices/quantities passed through from input |
| P3 | Config completeness | PASS | Module has no config (pure formatter — no configurable parameters by design) |
| P4 | .mli coverage | PASS | `weinstein_order_gen.mli` present; `from_transitions` and `suggested_order` exported |
| P5 | Internal helpers prefixed with `_` | PASS | `_shares_of_position`, `_entry_side_of_position_side`, `_exit_side_of_position_side`, `_translate_transition` all prefixed |
| P6 | Tests use matchers library | PASS | `assert_that`, `elements_are`, `size_is`, `equal_to` used throughout |
| A1 | Core module modifications | PASS | Zero modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No analysis/ → trading/ imports | PASS | New module is in trading/ — no cross-layer violation |
| A3 | No unnecessary existing module modifications | PASS | Only new files added; no existing file touched |

### Verdict

APPROVED

---

## 2026-04-08 — Behavioral Review (branch: feat/weinstein, commit 8057a07b)

Date: 2026-04-08
Reviewer: qc-behavioral
Branch reviewed: feat/weinstein

### Reference: eng-design-3-portfolio-stops.md §"Order Generation"

Design spec states:
- Input: `Position.transition list` from `strategy.on_market_close` + position quantity lookup
- Output: Suggested broker orders (human reviews before placing)
- `CreateEntering` → `StopLimit` entry
- `UpdateRiskParams { stop_loss_price = Some p }` → `Stop` at p
- `TriggerExit` → `Market` exit
- All other transitions (simulator-internal) → ignored
- Strategy-agnostic: no Weinstein-specific logic

### Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| B1 | Correct location (trading/weinstein/order_gen/) | PASS | Module lives at `trading/trading/weinstein/order_gen/` — correct layer |
| B2 | Input is Position.transition list | PASS | `from_transitions ~transitions:Position.transition list` — matches spec |
| B3 | No sizing decisions | PASS | Module only reads `target_quantity` from the transition (already decided by strategy); no new sizing logic |
| B4 | No screener input | PASS | No dependency on Screener, Stock_analysis, or Macro modules |
| B5 | Strategy-agnostic | PASS | Depends only on `Trading_strategy.Position` and `Trading_base.Types` — no Weinstein-specific types |
| B6 | CreateEntering → StopLimit | PASS | Long: Buy StopLimit at entry_price; Short: Sell StopLimit at entry_price — matches spec |
| B7 | UpdateRiskParams + stop → Stop order | PASS | Stop order at stop_loss_price for existing position shares |
| B8 | UpdateRiskParams no stop → ignored | PASS | `stop_loss_price = None` case returns None — no output |
| B9 | TriggerExit → Market exit | PASS | Market exit for full position quantity; side inverted correctly (Long → Sell, Short → Buy) |
| B10 | Simulator transitions ignored | PASS | EntryFill, EntryComplete, CancelEntry, ExitFill, ExitComplete all return None |
| B11 | Unknown position_id → skipped | PASS | `get_position` returns None → transition skipped; no crash |
| B12 | Tests assert domain outcomes | PASS | 11 tests cover all 3 strategy-triggered kinds, simulator-internal ignored, unknown position, multi-transition, empty list |

### Verdict

APPROVED

---

## Combined Result

overall_qc: APPROVED
Both structural and behavioral QC passed on 2026-04-08.
Feature is in Integration Queue — ready to merge to main pending human decision.

---

## Prior review records (superseded)

### 2026-04-05 — NEEDS_REWORK (branch: portfolio-stops/trading-state-sexp)

Reviewed a stale/wrong branch. That branch's work has since been merged to main. Review no longer applicable.

### 2026-04-07 — APPROVED (branch: feat/portfolio-stops-order-gen, PR #214) — VOID

Both structural and behavioral QC returned APPROVED, but the implementation was subsequently
identified as repeating the same design mistake as PR #203: order_gen was in `analysis/weinstein/`
(wrong location), took screener candidates (wrong input), and made sizing decisions (wrong
responsibility). PR #214 was closed. This APPROVED verdict is void.
