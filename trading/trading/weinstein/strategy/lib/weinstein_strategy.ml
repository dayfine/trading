open Core
open Trading_strategy

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

(** Collect weekly bars for a symbol from the price adapter. *)
let _collect_bars ~(get_price : Strategy_interface.get_price_fn)
    ~(get_indicator : Strategy_interface.get_indicator_fn) ~symbol ~(n : int) :
    Types.Daily_price.t list =
  (* Strategy interface provides only the current bar — full history not yet
     accessible. Stage and macro analysers degrade gracefully with < 30 bars. *)
  ignore (get_indicator, n);
  match get_price symbol with Some bar -> [ bar ] | None -> []

let _make_exit_transition ~(pos : Position.t) ~current_date ~state ~bar =
  let actual_price = bar.Types.Daily_price.low_price in
  let exit_reason =
    Position.StopLoss
      {
        stop_price = Weinstein_stops.get_stop_level state;
        actual_price;
        loss_percent = 0.0;
      }
  in
  {
    Position.position_id = pos.id;
    date = current_date;
    kind = Position.TriggerExit { exit_reason; exit_price = actual_price };
  }

let _make_adjust_transition ~(pos : Position.t) ~current_date
    ~(risk_params : Position.risk_params) ~new_level =
  let new_risk_params =
    {
      Position.stop_loss_price = Some new_level;
      take_profit_price = risk_params.take_profit_price;
      max_hold_days = risk_params.max_hold_days;
    }
  in
  {
    Position.position_id = pos.id;
    date = current_date;
    kind = Position.UpdateRiskParams { new_risk_params };
  }

(** Process stop logic for one held position. Returns (exit_transition option,
    adjust_transition option). *)
let _handle_stop ~config ~(pos : Position.t)
    ~(risk_params : Position.risk_params) ~state ~bar ~stop_states ~ticker =
  let current_date = bar.Types.Daily_price.date in
  (* Use Flat as conservative MA direction placeholder — will use computed
     slope when we have full weekly bar history. *)
  let new_state, event =
    Weinstein_stops.update ~config:config.stops_config ~side:pos.Position.side
      ~state ~current_bar:bar ~ma_value:bar.close_price
      ~ma_direction:Weinstein_types.Flat
      ~stage:(Weinstein_types.Stage2 { weeks_advancing = 1; late = false })
  in
  stop_states := Map.set !stop_states ~key:ticker ~data:new_state;
  match event with
  | Weinstein_stops.Stop_hit _ ->
      (Some (_make_exit_transition ~pos ~current_date ~state ~bar), None)
  | Weinstein_stops.Stop_raised { new_level; _ } ->
      ( None,
        Some
          (_make_adjust_transition ~pos ~current_date ~risk_params ~new_level)
      )
  | _ -> (None, None)

(** Process stop for one position; returns updated (exits, adjusts) accumulator.
*)
let _process_stop ~config ~stop_states ~get_price ticker (pos : Position.t)
    (exits, adjusts) =
  match
    (Position.get_state pos, Map.find !stop_states ticker, get_price ticker)
  with
  | Position.Holding h, Some state, Some bar -> (
      match
        _handle_stop ~config ~pos ~risk_params:h.risk_params ~state ~bar
          ~stop_states ~ticker
      with
      | Some exit_tr, _ -> (exit_tr :: exits, adjusts)
      | _, Some adj_tr -> (exits, adj_tr :: adjusts)
      | None, None -> (exits, adjusts))
  | _ -> (exits, adjusts)

(** Update stops for all held positions. Returns (exit_transitions,
    adjust_transitions). *)
let _update_stops ~config ~positions ~get_price ~stop_states =
  Map.fold positions ~init:([], []) ~f:(fun ~key:ticker ~data:pos acc ->
      _process_stop ~config ~stop_states ~get_price ticker pos acc)

(** Try to build a CreateEntering transition for one screened candidate.
    Registers the initial stop state as a side effect. Returns None if the
    candidate is un-sizeable (portfolio value unknown until Slice 2). *)
let _make_entry_transition ~config ~stop_states ~portfolio_value
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
    Some
      {
        Position.position_id = id;
        date = Date.today ~zone:Time_float.Zone.utc;
        kind;
      }

(** Generate CreateEntering transitions for top screener candidates. *)
let _entries_from_candidates ~config ~candidates ~stop_states ~positions =
  let held = Map.keys positions in
  (* Placeholder: portfolio value = 0 until Slice 2 supplies real cash. *)
  let snapshot = Portfolio_risk.snapshot ~cash:0.0 ~positions:[] () in
  let make_entry =
    _make_entry_transition ~config ~stop_states
      ~portfolio_value:snapshot.total_value
  in
  candidates
  |> List.filter ~f:(fun (c : Screener.scored_candidate) ->
      not (List.mem held c.ticker ~equal:String.equal))
  |> List.filter_map ~f:make_entry

(** Screen the universe for buy candidates. Returns entry transitions. *)
let _screen_universe ~config ~get_price ~get_indicator ~index_bars ~macro_trend
    ~stop_states ~positions =
  let sector_map = Hashtbl.create (module String) in
  let _analyze_ticker ticker =
    let bars =
      _collect_bars ~get_price ~get_indicator ~symbol:ticker
        ~n:config.lookback_bars
    in
    if List.is_empty bars then None
    else
      let as_of_date =
        match List.last bars with
        | Some b -> b.Types.Daily_price.date
        | None -> Date.today ~zone:Time_float.Zone.utc
      in
      Some
        (Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
           ~bars ~benchmark_bars:index_bars ~prior_stage:None ~as_of_date)
  in
  let stocks = List.filter_map config.universe ~f:_analyze_ticker in
  let screen_result =
    Screener.screen ~config:config.screening_config ~macro_trend ~sector_map
      ~stocks ~held_tickers:(Map.keys positions)
  in
  _entries_from_candidates ~config
    ~candidates:screen_result.Screener.buy_candidates ~stop_states ~positions

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

let _on_market_close ~config ~stop_states ~prior_macro ~get_price ~get_indicator
    ~(portfolio : Portfolio_view.t) =
  let positions = portfolio.positions in
  let exit_transitions, adjust_transitions =
    _update_stops ~config ~positions ~get_price ~stop_states
  in
  let index_bars =
    _collect_bars ~get_price ~get_indicator ~symbol:config.index_symbol
      ~n:config.lookback_bars
  in
  let entry_transitions =
    if not (_is_screening_day index_bars) then []
    else
      let macro_result =
        Macro.analyze ~config:config.macro_config ~index_bars ~ad_bars:[]
          ~global_index_bars:[] ~prior_stage:None ~prior:None
      in
      prior_macro := macro_result.trend;
      if Weinstein_types.(equal_market_trend !prior_macro Bearish) then []
      else
        _screen_universe ~config ~get_price ~get_indicator ~index_bars
          ~macro_trend:macro_result.trend ~stop_states ~positions
  in
  Ok
    {
      Strategy_interface.transitions =
        exit_transitions @ adjust_transitions @ entry_transitions;
    }

let make ?(initial_stop_states = String.Map.empty) config =
  let stop_states = ref initial_stop_states in
  let prior_macro : Weinstein_types.market_trend ref =
    ref Weinstein_types.Neutral
  in
  let module M = struct
    let name = name
    let on_market_close = _on_market_close ~config ~stop_states ~prior_macro
  end in
  (module M : Strategy_interface.STRATEGY)
