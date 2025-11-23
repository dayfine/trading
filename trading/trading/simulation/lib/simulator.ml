(** Simulation engine for backtesting trading strategies *)

open Core

type step_result = {
  date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  trades : Trading_base.Types.trade list;
}

type run_result = {
  steps : step_result list;
  final_portfolio : Trading_portfolio.Portfolio.t;
}

type t = {
  config : Sim_types.simulation_config;
  prices : Sim_types.symbol_prices list; [@warning "-69"]
  current_date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
}

let create ~config ~prices =
  let portfolio =
    Trading_portfolio.Portfolio.create
      ~initial_cash:config.Sim_types.initial_cash ()
  in
  Ok { config; prices; current_date = config.Sim_types.start_date; portfolio }

let current_date t = t.current_date
let is_complete t = Date.( >= ) t.current_date t.config.end_date

let step t =
  if is_complete t then
    Error (Status.invalid_argument_error "Simulation already complete")
  else
    (* Stub: just advance the date, no actual trading *)
    let next_date = Date.add_days t.current_date 1 in
    let step_result =
      { date = t.current_date; portfolio = t.portfolio; trades = [] }
    in
    let t' = { t with current_date = next_date } in
    Ok (t', step_result)

let run t =
  let rec loop t acc =
    if is_complete t then
      Ok { steps = List.rev acc; final_portfolio = t.portfolio }
    else
      match step t with
      | Error e -> Error e
      | Ok (t', step_result) -> loop t' (step_result :: acc)
  in
  loop t []
