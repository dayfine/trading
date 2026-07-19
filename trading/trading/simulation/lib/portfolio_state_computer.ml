(** Portfolio state metric computer — captures end-of-simulation state:
    OpenPositionCount, OpenPositionsValue, UnrealizedPnl, TradeFrequency.

    Reads {!Portfolio_summary} fields off [step_result.portfolio]; this computer
    needs neither lots nor trade history, so the skinny projection introduced
    for Fix B (see [dev/notes/15y-memory-cliff-2026-05-08.md]) suffices. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types
module Portfolio_summary = Trading_simulation_types.Portfolio_summary

type state = {
  last_step : Simulator_types.step_result option;
      (** Last step seen, regardless of whether it is a trading day. Drives
          [OpenPositionCount], which is independent of price-bar availability.
      *)
  last_marked_step : Simulator_types.step_result option;
      (** Last step whose [portfolio_value] is a real mark-to-market (cash +
          position market values). Held positions are valued via cache +
          avg-cost fallback chain in [Simulator._resolve_price] so the cash-only
          collapse no longer fires; this filter remains as a safety net for any
          residual cash-only step (e.g. zero-position runs) so
          [OpenPositionsValue] / [UnrealizedPnl] reflect actual end-of-sim
          state. See [_is_marked_to_market]. *)
  total_trades : int;
}

(** True if [step] has a trustworthy mark-to-market [portfolio_value].

    Heuristic (mirrors [Backtest.Runner._is_trading_day] at
    [trading/trading/backtest/lib/runner.ml]): when there are no open positions,
    [portfolio_value = cash] is trivially correct. When there are open
    positions, [portfolio_value] should differ measurably from cash — the
    simulator's cache + avg-cost fallback in [_resolve_price] now guarantees
    every held position is priced, so a step where the marked position value is
    ~0 despite open positions indicates the cash-only-collapse edge case that
    the metric computers should still skip.

    Keyed off [position_value_total] (the debit-free marked position value)
    rather than [portfolio_value - current_cash]: once margin M1b-2 makes
    [portfolio_value] debit-net, [portfolio_value - cash] equals
    [Σqty*close - long_margin_debit], which can collapse to ~0 for a
    highly-levered book (positions ≈ debit) and spuriously classify a real
    marked step as unmarked. At the default cash account (debit 0) the two are
    equivalent. *)
let _is_marked_to_market (step : Simulator_types.step_result) =
  let has_positions = Portfolio_summary.positions_count step.portfolio > 0 in
  (not has_positions) || Float.(abs step.portfolio.position_value_total > 1e-2)

let _trade_frequency ~total_trades ~start_date ~end_date =
  let days = Float.of_int (Date.diff end_date start_date) in
  let months = days /. 30.44 in
  if Float.(months <= 0.0) then 0.0 else Float.of_int total_trades /. months

(** Build metric set. [position_step] is the step that determines
    [OpenPositionCount] (always the absolute last step). [marked_step] is the
    step that determines [OpenPositionsValue] / [UnrealizedPnl] (the last
    mark-to-market step, which may or may not equal [position_step]). *)
let _metrics_from_step ~(position_step : Simulator_types.step_result)
    ~(marked_step : Simulator_types.step_result) ~total_trades ~start_date
    ~end_date =
  (* OpenPositionsValue is the marked value of held positions (Σ qty*close),
     carried debit-free on the skinny summary as [position_value_total]. Deriving
     it as [portfolio_value - current_cash] would be wrong once margin M1b-2 makes
     [portfolio_value] debit-net (it would yield Σqty*close - long_margin_debit);
     [position_value_total] is already the pure position value the simulator
     computes. At the default cash account (debit 0) the two coincide, so
     pre-M1b metrics are bit-identical. *)
  let open_positions_value = marked_step.portfolio.position_value_total in
  let cost_basis =
    Portfolio_summary.position_cost_basis_total marked_step.portfolio
  in
  let unrealized_pnl = open_positions_value -. cost_basis in
  Metric_types.of_alist_exn
    [
      ( OpenPositionCount,
        Float.of_int (Portfolio_summary.positions_count position_step.portfolio)
      );
      (OpenPositionsValue, open_positions_value);
      (UnrealizedPnl, unrealized_pnl);
      (TradeFrequency, _trade_frequency ~total_trades ~start_date ~end_date);
    ]

let _update ~state ~step =
  {
    last_step = Some step;
    last_marked_step =
      (if _is_marked_to_market step then Some step else state.last_marked_step);
    total_trades = state.total_trades + List.length step.trades;
  }

(** Compute metrics from [state] when a last step exists. If no marked-to-market
    step was recorded (degenerate: all steps were non-trading days with open
    positions), falls back to [position_step] so [OpenPositionsValue] /
    [UnrealizedPnl] both read as 0. *)
let _metrics_for_last_steps ~state ~(config : Simulator_types.config)
    position_step =
  let marked_step =
    Option.value state.last_marked_step ~default:position_step
  in
  _metrics_from_step ~position_step ~marked_step
    ~total_trades:state.total_trades ~start_date:config.start_date
    ~end_date:config.end_date

let _finalize ~state ~(config : Simulator_types.config) =
  match state.last_step with
  | None -> Metric_types.empty
  | Some position_step -> _metrics_for_last_steps ~state ~config position_step

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "portfolio_state";
      init =
        (fun ~config:_ ->
          { last_step = None; last_marked_step = None; total_trades = 0 });
      update = _update;
      finalize = _finalize;
    }
