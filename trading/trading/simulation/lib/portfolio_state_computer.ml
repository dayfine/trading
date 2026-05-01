(** Portfolio state metric computer — captures end-of-simulation state:
    OpenPositionCount, OpenPositionsValue, UnrealizedPnl, TradeFrequency. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type state = {
  last_step : Simulator_types.step_result option;
      (** Last step seen, regardless of whether it is a trading day. Drives
          [OpenPositionCount], which is independent of price-bar availability.
      *)
  last_marked_step : Simulator_types.step_result option;
      (** Last step whose [portfolio_value] is a real mark-to-market (cash +
          position market values). On non-trading days (weekends, holidays) or
          when price bars for open-position symbols are missing, the simulator
          falls back to [portfolio_value = current_cash] — such steps are
          excluded here so [OpenPositionsValue] / [UnrealizedPnl] reflect actual
          end-of-sim state. See [_is_marked_to_market]. *)
  total_trades : int;
}

(** True if [step] has a trustworthy mark-to-market [portfolio_value].

    Heuristic (mirrors [Backtest.Runner._is_trading_day] at
    [trading/trading/backtest/lib/runner.ml]): when there are no open positions,
    [portfolio_value = cash] is trivially correct. When there are open
    positions, [portfolio_value] should differ measurably from cash — otherwise
    the simulator's [_compute_portfolio_value] fell back to cash because no
    price bars were available for that date. *)
let _is_marked_to_market (step : Simulator_types.step_result) =
  let cash = step.portfolio.Trading_portfolio.Portfolio.current_cash in
  let has_positions =
    not (List.is_empty step.portfolio.Trading_portfolio.Portfolio.positions)
  in
  (not has_positions) || Float.(abs (step.portfolio_value -. cash) > 1e-2)

let _trade_frequency ~total_trades ~start_date ~end_date =
  let days = Float.of_int (Date.diff end_date start_date) in
  let months = days /. 30.44 in
  if Float.(months <= 0.0) then 0.0 else Float.of_int total_trades /. months

(** Sum of [position_cost_basis] across the portfolio's currently-held
    positions. For longs this is positive (qty>0 times avg_cost>0); for shorts
    it is negative (qty<0 times avg_cost>0). Subtracting this signed sum from
    [OpenPositionsValue] yields the signed-qty unrealized P&L formula in the
    [UnrealizedPnl] metric description. *)
let _open_positions_cost_basis (portfolio : Trading_portfolio.Portfolio.t) =
  List.fold portfolio.positions ~init:0.0 ~f:(fun acc pos ->
      acc +. Trading_portfolio.Calculations.position_cost_basis pos)

(** Build metric set. [position_step] is the step that determines
    [OpenPositionCount] (always the absolute last step). [marked_step] is the
    step that determines [OpenPositionsValue] / [UnrealizedPnl] (the last
    mark-to-market step, which may or may not equal [position_step]). *)
let _metrics_from_step ~(position_step : Simulator_types.step_result)
    ~(marked_step : Simulator_types.step_result) ~total_trades ~start_date
    ~end_date =
  let open_positions_value =
    marked_step.portfolio_value
    -. marked_step.portfolio.Trading_portfolio.Portfolio.current_cash
  in
  let cost_basis = _open_positions_cost_basis marked_step.portfolio in
  let unrealized_pnl = open_positions_value -. cost_basis in
  Metric_types.of_alist_exn
    [
      ( OpenPositionCount,
        Float.of_int (List.length position_step.portfolio.positions) );
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

let _finalize ~state ~(config : Simulator_types.config) =
  match state.last_step with
  | None -> Metric_types.empty
  | Some position_step ->
      (* If no step in the sim was marked-to-market (degenerate: e.g. all
         steps were non-trading days with open positions), fall back to the
         last step. OpenPositionsValue / UnrealizedPnl will then be 0 as
         before — not great, but consistent with pre-fix behaviour for that
         edge case. *)
      let marked_step =
        Option.value state.last_marked_step ~default:position_step
      in
      _metrics_from_step ~position_step ~marked_step
        ~total_trades:state.total_trades ~start_date:config.start_date
        ~end_date:config.end_date

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
