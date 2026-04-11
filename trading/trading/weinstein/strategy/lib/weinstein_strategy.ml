open Core
open Trading_strategy
module Bar_history = Bar_history
module Stops_runner = Stops_runner

module Ad_bars = Ad_bars
(** NYSE advance/decline breadth data loader. Exposed as a top-level submodule
    so tests and external callers (e.g. live-mode boot) can load NYSE breadth
    data before wiring it into the strategy. *)

type config = {
  universe : string list;
  index_symbol : string;
  stage_config : Stage.config;
  macro_config : Macro.config;
  screening_config : Screener.config;
  portfolio_config : Portfolio_risk.config;
  stops_config : Weinstein_stops.config;
  initial_stop_buffer : float;
  lookback_bars : int;
}

let default_config ~universe ~index_symbol =
  {
    universe;
    index_symbol;
    stage_config = Stage.default_config;
    macro_config = Macro.default_config;
    screening_config = Screener.default_config;
    portfolio_config = Portfolio_risk.default_config;
    stops_config = Weinstein_stops.default_config;
    initial_stop_buffer = 1.02;
    lookback_bars = 52;
  }

let name = "Weinstein"

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let _position_counter = ref 0

let _gen_position_id symbol =
  Int.incr _position_counter;
  Printf.sprintf "%s-wein-%d" symbol !_position_counter

(** Try to build a CreateEntering transition for one screened candidate.
    Registers the initial stop state as a side effect. Returns None if the
    candidate is un-sizeable (zero portfolio value or zero shares). *)
let _make_entry_transition ~config ~stop_states ~portfolio_value ~current_date
    (cand : Screener.scored_candidate) =
  let sizing =
    Portfolio_risk.compute_position_size ~config:config.portfolio_config
      ~portfolio_value ~entry_price:cand.suggested_entry
      ~stop_price:cand.suggested_stop ()
  in
  if sizing.shares = 0 then None
  else
    let id = _gen_position_id cand.ticker in
    let initial_stop =
      Weinstein_stops.compute_initial_stop ~config:config.stops_config
        ~side:Trading_base.Types.Long
        ~reference_level:(cand.suggested_stop *. config.initial_stop_buffer)
    in
    stop_states := Map.set !stop_states ~key:cand.ticker ~data:initial_stop;
    let description =
      Printf.sprintf "Weinstein %s: %s"
        (Weinstein_types.grade_to_string cand.grade)
        (String.concat ~sep:"; " cand.rationale)
    in
    let reasoning = Position.ManualDecision { description } in
    let kind =
      Position.CreateEntering
        {
          symbol = cand.ticker;
          side = Trading_base.Types.Long;
          target_quantity = Float.of_int sizing.shares;
          entry_price = cand.suggested_entry;
          reasoning;
        }
    in
    Some { Position.position_id = id; date = current_date; kind }

(** Generate CreateEntering transitions for top screener candidates. *)
let _entries_from_candidates ~config ~candidates ~stop_states
    ~(portfolio : Portfolio_view.t) ~get_price ~current_date =
  let held = Map.keys portfolio.positions in
  let portfolio_value = Portfolio_view.portfolio_value portfolio ~get_price in
  let make_entry =
    _make_entry_transition ~config ~stop_states ~portfolio_value ~current_date
  in
  candidates
  |> List.filter ~f:(fun (c : Screener.scored_candidate) ->
      not (List.mem held c.ticker ~equal:String.equal))
  |> List.filter_map ~f:make_entry

(** Screen the universe for buy candidates. Returns entry transitions. *)
let _screen_universe ~config ~index_bars ~macro_trend ~stop_states
    ~(portfolio : Portfolio_view.t) ~get_price ~bar_history ~prior_stages
    ~current_date =
  let sector_map = Hashtbl.create (module String) in
  let _analyze_ticker ticker =
    let bars =
      Bar_history.weekly_bars_for bar_history ~symbol:ticker
        ~n:config.lookback_bars
    in
    if List.is_empty bars then None
    else
      let as_of_date =
        match List.last bars with
        | Some b -> b.Types.Daily_price.date
        | None -> current_date
      in
      let prior_stage = Hashtbl.find prior_stages ticker in
      let result =
        Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
          ~bars ~benchmark_bars:index_bars ~prior_stage ~as_of_date
      in
      Hashtbl.set prior_stages ~key:ticker ~data:result.stage.stage;
      Some result
  in
  let stocks = List.filter_map config.universe ~f:_analyze_ticker in
  let screen_result =
    Screener.screen ~config:config.screening_config ~macro_trend ~sector_map
      ~stocks
      ~held_tickers:(Map.keys portfolio.positions)
  in
  _entries_from_candidates ~config
    ~candidates:screen_result.Screener.buy_candidates ~stop_states ~portfolio
    ~get_price ~current_date

(* ------------------------------------------------------------------ *)
(* make                                                                  *)
(* ------------------------------------------------------------------ *)

(** Stops are adjusted daily; screening runs only on Fridays (weekly review). *)
let _is_screening_day index_bars =
  match List.last index_bars with
  | None -> false
  | Some bar ->
      Date.day_of_week bar.Types.Daily_price.date
      |> Day_of_week.equal Day_of_week.Fri

let _on_market_close ~config ~ad_bars ~stop_states ~prior_macro ~bar_history
    ~prior_stages ~get_price ~get_indicator:_ ~(portfolio : Portfolio_view.t) =
  let positions = portfolio.positions in
  let all_symbols = config.index_symbol :: config.universe in
  Bar_history.accumulate bar_history ~get_price ~symbols:all_symbols;
  let current_date =
    match get_price config.index_symbol with
    | Some bar -> bar.Types.Daily_price.date
    | None -> Date.today ~zone:Time_float.Zone.utc
  in
  let exit_transitions, adjust_transitions =
    Stops_runner.update ~stops_config:config.stops_config
      ~stage_config:config.stage_config ~lookback_bars:config.lookback_bars
      ~positions ~get_price ~stop_states ~bar_history ~prior_stages
  in
  let index_bars =
    Bar_history.weekly_bars_for bar_history ~symbol:config.index_symbol
      ~n:config.lookback_bars
  in
  let entry_transitions =
    if not (_is_screening_day index_bars) then []
    else
      let index_prior_stage = Hashtbl.find prior_stages config.index_symbol in
      let macro_result =
        Macro.analyze ~config:config.macro_config ~index_bars ~ad_bars
          ~global_index_bars:[] ~prior_stage:index_prior_stage ~prior:None
      in
      prior_macro := macro_result.trend;
      if Weinstein_types.(equal_market_trend !prior_macro Bearish) then []
      else
        _screen_universe ~config ~index_bars ~macro_trend:macro_result.trend
          ~stop_states ~portfolio ~get_price ~bar_history ~prior_stages
          ~current_date
  in
  Ok
    {
      Strategy_interface.transitions =
        exit_transitions @ adjust_transitions @ entry_transitions;
    }

let make ?(initial_stop_states = String.Map.empty) ?(ad_bars = []) config =
  let stop_states = ref initial_stop_states in
  let prior_macro : Weinstein_types.market_trend ref =
    ref Weinstein_types.Neutral
  in
  let bar_history = Bar_history.create () in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let module M = struct
    let name = name

    let on_market_close =
      _on_market_close ~config ~ad_bars ~stop_states ~prior_macro ~bar_history
        ~prior_stages
  end in
  (module M : Strategy_interface.STRATEGY)
