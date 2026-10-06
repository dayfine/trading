(** Sharpe ratio metric computer. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types
module Cash_yield = Trading_simulation_cash_yield.Cash_yield

type state = {
  marks : (Date.t * float) list;  (** Trading-day marks, newest first. *)
  risk_free_rate : float;
  cash_yield : Cash_yield.t option;
}

let _mean = function
  | [] -> 0.0
  | values ->
      let sum = List.fold values ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length values)

let _sq_diff mean acc x =
  let diff = x -. mean in
  acc +. (diff *. diff)

let _std = function
  | [] | [ _ ] -> 0.0
  | values ->
      let mean = _mean values in
      let sum_sq_diff = List.fold values ~init:0.0 ~f:(_sq_diff mean) in
      Float.sqrt (sum_sq_diff /. Float.of_int (List.length values))

let _return ~prev ~curr =
  if Float.(prev = 0.0) then 0.0 else (curr -. prev) /. prev

(* Per-period returns between consecutive marks, each with the two dates it
   spans. Requires at least two marks. *)
let _period_returns marks =
  List.zip_exn (List.drop_last_exn marks) (List.tl_exn marks)
  |> List.map ~f:(fun ((d0, v0), (d1, v1)) ->
      (d0, d1, _return ~prev:v0 ~curr:v1))

let _compute_sharpe daily_returns risk_free_rate =
  match daily_returns with
  | [] | [ _ ] -> 0.0
  | _ ->
      let mean_return = _mean daily_returns in
      let std_return = _std daily_returns in
      if Float.(std_return = 0.0) then 0.0
      else
        let tdpy = Metric_computer_utils.trading_days_per_year in
        let excess = mean_return -. (risk_free_rate /. tdpy) in
        excess /. std_return *. Float.sqrt tdpy

(* Excess over the cash rate each period actually earned (#3137): the period's
   risk-free is the cash yield accrued over the calendar days between the two
   marks, so an all-cash book scores ~0. *)
let _period_excess cash_yield (d0, d1, ret) =
  match Cash_yield.period_rate cash_yield ~from_:d0 ~to_:d1 with
  | Ok rf -> ret -. rf
  | Error e -> failwith ("Sharpe_computer: " ^ Status.show e)

let _sharpe_of_marks ~risk_free_rate ~cash_yield marks =
  match marks with
  | [] | [ _ ] -> 0.0
  | _ -> (
      let periods = _period_returns marks in
      match cash_yield with
      | None ->
          _compute_sharpe
            (List.map periods ~f:(fun (_, _, r) -> r))
            risk_free_rate
      | Some cy -> _compute_sharpe (List.map periods ~f:(_period_excess cy)) 0.0
      )

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    {
      state with
      marks =
        (step.Simulator_types.date, step.Simulator_types.portfolio_value)
        :: state.marks;
    }

let _finalize ~state ~config:_ =
  let sharpe =
    _sharpe_of_marks ~risk_free_rate:state.risk_free_rate
      ~cash_yield:state.cash_yield (List.rev state.marks)
  in
  Metric_types.singleton SharpeRatio sharpe

let computer ?(risk_free_rate = 0.0) ?cash_yield () :
    Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "sharpe_ratio";
      init = (fun ~config:_ -> { marks = []; risk_free_rate; cash_yield });
      update = _update;
      finalize = _finalize;
    }
