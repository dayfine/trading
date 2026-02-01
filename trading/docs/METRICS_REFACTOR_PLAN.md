# Metrics Module Refactoring Plan

This document describes the refactoring of the metrics module to support a generic metric framework with fold-based computation for advanced metrics like Sharpe ratio and maximum drawdown.

## Overview

The refactoring adds:
1. Generic `metric` type with value, unit, name, description
2. Fold-based metric computation model over simulation steps
3. New metrics: Sharpe ratio, maximum drawdown
4. Simulator integration to compute and return metrics on completion
5. Backward compatibility with existing `trade_metrics` and `summary_stats`

## Design Decisions

- **Record-of-functions** approach for metric computers (simpler than first-class modules, matches codebase style)
- **Type-erased wrapper** (`any_metric_computer`) for heterogeneous collections
- Added `portfolio_value` field to `step_result` for accurate Sharpe/drawdown calculation
- `run_result` type placed in `Metrics` module to avoid dependency cycle between Metrics and Simulator
- `run_with_metrics` function placed in `Metric_computers` module

## Files Modified/Created

| File | Action |
|------|--------|
| `trading/simulation/lib/metrics.mli` | Extended with generic types |
| `trading/simulation/lib/metrics.ml` | Extended with implementations |
| `trading/simulation/lib/metric_computers.mli` | NEW - metric computer implementations interface |
| `trading/simulation/lib/metric_computers.ml` | NEW - sharpe, drawdown, summary computers |
| `trading/simulation/lib/simulator.mli` | Added `portfolio_value` to step_result, `get_config` |
| `trading/simulation/lib/simulator.ml` | Compute portfolio value, added accessor |
| `trading/simulation/lib/dune` | Added `metric_computers` module |
| `trading/simulation/test/test_metrics.ml` | NEW - unit tests for metrics |
| `trading/simulation/test/dune` | Added test_metrics |
| `trading/simulation/test/test_simulator.ml` | Updated for new step_result field |

## Type Definitions

### Generic Metric Types (metrics.mli)

```ocaml
type metric_unit =
  | Dollars    (** Monetary value in dollars *)
  | Percent    (** Percentage value (0-100 scale) *)
  | Days       (** Time duration in days *)
  | Count      (** Discrete count *)
  | Ratio      (** Dimensionless ratio *)
[@@deriving show, eq]

type metric = {
  name : string;           (* e.g., "sharpe_ratio" *)
  display_name : string;   (* e.g., "Sharpe Ratio" *)
  description : string;
  value : float;
  unit : metric_unit;
}
[@@deriving show, eq]

type metric_set = metric list
```

### Metric Computer Abstraction (metrics.mli)

```ocaml
type 'state metric_computer = {
  name : string;
  init : config:Simulator.config -> 'state;
  update : state:'state -> step:Simulator.step_result -> 'state;
  finalize : state:'state -> config:Simulator.config -> metric list;
}

type any_metric_computer  (* type-erased wrapper *)

val wrap_computer : 'state metric_computer -> any_metric_computer
val compute_metrics :
  computers:any_metric_computer list ->
  config:Simulator.config ->
  steps:Simulator.step_result list ->
  metric_set
```

### Extended step_result (simulator.mli)

```ocaml
type step_result = {
  date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  portfolio_value : float;  (* NEW: cash + position values *)
  trades : Trading_base.Types.trade list;
  orders_submitted : Trading_orders.Types.order list;
}
```

### Run Result Type (metrics.mli)

```ocaml
type run_result = {
  steps : Simulator.step_result list;
  final_portfolio : Trading_portfolio.Portfolio.t;
  metrics : metric_set;
}
```

### Running with Metrics (metric_computers.mli)

```ocaml
val run_with_metrics :
  ?computers:any_metric_computer list ->
  Simulator.t ->
  run_result Status.status_or
```

## Implementation Phases

**Status: All phases completed ✅**

### Phase 1: Core Generic Types ✅
1. ✅ Add `metric_unit`, `metric`, `metric_set` types to metrics.mli/ml
2. ✅ Add `metric_computer`, `any_metric_computer` types
3. ✅ Add `wrap_computer`, `compute_metrics` functions
4. ✅ Add `summary_stats_to_metrics` conversion
5. ✅ Add `find_metric`, `format_metric`, `format_metrics` helpers

### Phase 2: Extend step_result ✅
1. ✅ Add `portfolio_value` field to `step_result`
2. ✅ Add `_compute_portfolio_value` helper in simulator.ml
3. ✅ Update `step` function to compute portfolio value
4. ✅ Update existing tests for new field

### Phase 3: Metric Computers (new files) ✅
1. ✅ Create `metric_computers.mli` / `metric_computers.ml`
2. ✅ Implement `summary_computer` (wraps existing compute_summary)
3. ✅ Implement `sharpe_ratio_computer`:
   - Collect daily portfolio values
   - Compute daily returns
   - Sharpe = (mean - rf) / std * sqrt(252)
4. ✅ Implement `max_drawdown_computer`:
   - Track peak value
   - Track max drawdown (peak - trough) / peak
5. ✅ Add `default_computers` function
6. ✅ Update dune

### Phase 4: Simulator Integration ✅
1. ✅ Add `run_result` type to Metrics module
2. ✅ Add `run_with_metrics` to Metric_computers module
3. ✅ Add `get_config` accessor to Simulator

### Phase 5: Tests ✅
1. ✅ Create `test_metrics.ml` with tests for:
   - Metric type derivations (show, eq)
   - summary_stats_to_metrics conversion
   - compute_metrics combining multiple computers
   - Sharpe ratio edge cases (zero variance, positive/negative)
   - Max drawdown edge cases (no loss, captures largest decline)
   - Backward compatibility (existing API unchanged)

### Phase 6: Polish ✅
1. ✅ Run `dune fmt`
2. ✅ Verify all tests pass

## Key Metric Formulas

### Sharpe Ratio

```
daily_returns[i] = (value[i] - value[i-1]) / value[i-1]
sharpe = (mean(daily_returns) - risk_free_rate/252) / std(daily_returns) * sqrt(252)
```

Edge cases:
- Returns 0.0 if fewer than 2 data points
- Returns 0.0 if standard deviation is zero (no variance)

### Maximum Drawdown

```
For each step:
  peak = max(peak, current_value)
  drawdown = (peak - current_value) / peak
  max_drawdown = max(max_drawdown, drawdown)
```

Result is a percentage (0-100 scale).

## Usage Examples

### Computing Metrics with Default Computers

```ocaml
let sim = Simulator.create ~config ~deps in
match Metric_computers.run_with_metrics sim with
| Ok result ->
    Printf.printf "Final cash: $%.2f\n" result.final_portfolio.current_cash;
    Printf.printf "Metrics:\n%s\n" (Metrics.format_metrics result.metrics)
| Error err ->
    Printf.printf "Error: %s\n" (Status.show err)
```

### Using Custom Computers

```ocaml
let computers = [
  Metric_computers.sharpe_ratio_computer ~risk_free_rate:0.02 ();
  Metric_computers.max_drawdown_computer ();
] in
match Metric_computers.run_with_metrics ~computers sim with
| Ok result -> (* ... *)
| Error err -> (* ... *)
```

### Finding Specific Metrics

```ocaml
match Metrics.find_metric result.metrics ~name:"sharpe_ratio" with
| Some m -> Printf.printf "Sharpe: %.4f\n" m.value
| None -> Printf.printf "Sharpe ratio not computed\n"
```

## Verification

```bash
docker exec <container> bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build && dune runtest trading/simulation/'
```

## Backward Compatibility

- Existing `trade_metrics` and `summary_stats` types unchanged
- Existing `extract_round_trips` and `compute_summary` functions unchanged
- Existing `Simulator.run` function unchanged (returns tuple, not run_result)
- New `run_with_metrics` is opt-in via `Metric_computers` module
