(** Simulation engine for backtesting trading strategies *)

open Core

(** {1 Input Types} *)

type symbol_prices = { symbol : string; prices : Types.Daily_price.t list }
[@@deriving show, eq]

type config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  commission : Trading_engine.Types.commission_config;
}
[@@deriving show, eq]

type dependencies = { prices : symbol_prices list } [@@warning "-69"]

(** {1 Simulator Types} *)

type step_result = {
  date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  trades : Trading_base.Types.trade list;
}

type step_outcome =
  | Stepped of t * step_result
  | Completed of Trading_portfolio.Portfolio.t

and t = {
  config : config;
  deps : dependencies; [@warning "-69"]
  current_date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
}

(** {1 Creation} *)

let create ~config ~deps =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:config.initial_cash ()
  in
  { config; deps; current_date = config.start_date; portfolio }

(** {1 Running} *)

let _is_complete t = Date.( >= ) t.current_date t.config.end_date

let step t =
  if _is_complete t then Ok (Completed t.portfolio)
  else
    (* Stub: just advance the date, no actual trading *)
    let next_date = Date.add_days t.current_date 1 in
    let step_result =
      { date = t.current_date; portfolio = t.portfolio; trades = [] }
    in
    let t' = { t with current_date = next_date } in
    Ok (Stepped (t', step_result))

let run t =
  let rec loop t acc =
    match step t with
    | Error e -> Error e
    | Ok (Completed portfolio) -> Ok (List.rev acc, portfolio)
    | Ok (Stepped (t', step_result)) -> loop t' (step_result :: acc)
  in
  loop t []
