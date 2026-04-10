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

(** Accumulate today's bar for each symbol into the per-symbol bar history.
    Skips if the bar date is not strictly after the last recorded date
    (idempotent for repeated calls on the same day). *)
let _is_new_bar (existing : Types.Daily_price.t list) bar =
  match List.last existing with
  | None -> true
  | Some last -> Date.( > ) bar.Types.Daily_price.date last.date

let _append_bar_if_new bar_history ~symbol bar =
  let existing = Hashtbl.find bar_history symbol |> Option.value ~default:[] in
  if _is_new_bar existing bar then
    Hashtbl.set bar_history ~key:symbol ~data:(existing @ [ bar ])

let _accumulate_bars
    ~(bar_history : Types.Daily_price.t list Hashtbl.M(String).t)
    ~(get_price : Strategy_interface.get_price_fn) ~symbols =
  List.iter symbols ~f:(fun symbol ->
      get_price symbol
      |> Option.iter ~f:(_append_bar_if_new bar_history ~symbol))

(** Get weekly bars for a symbol from the accumulated daily history. *)
let _weekly_bars_for ~bar_history ~symbol ~n =
  let daily = Hashtbl.find bar_history symbol |> Option.value ~default:[] in
  let weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:true daily
  in
  let len = List.length weekly in
  if len <= n then weekly else List.drop weekly (len - n)

(** Compute MA direction for a symbol from its accumulated bar history.
    Uses and updates the per-symbol prior_stages map to improve stage
    classification accuracy (enables Stage1->Stage2 transition detection). *)
let _compute_ma_direction ~(config : config) ~bar_history ~prior_stages ~symbol
    =
  let weekly = _weekly_bars_for ~bar_history ~symbol ~n:config.lookback_bars in
  if List.length weekly < config.stage_config.ma_period then
    Weinstein_types.Flat
  else
    let prior_stage = Hashtbl.find prior_stages symbol in
    let result =
      Stage.classify ~config:config.stage_config ~bars:weekly ~prior_stage
    in
    Hashtbl.set prior_stages ~key:symbol ~data:result.stage;
    result.ma_direction

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
    ~(risk_params : Position.risk_params) ~state ~bar ~stop_states ~ticker
    ~bar_history ~prior_stages =
  let current_date = bar.Types.Daily_price.date in
  let ma_direction =
    _compute_ma_direction ~config ~bar_history ~prior_stages ~symbol:ticker
  in
  let new_state, event =
    Weinstein_stops.update ~config:config.stops_config ~side:pos.Position.side
      ~state ~current_bar:bar ~ma_value:bar.close_price ~ma_direction
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
let _process_stop ~config ~stop_states ~get_price ~bar_history ~prior_stages
    ticker (pos : Position.t) (exits, adjusts) =
  match
    (Position.get_state pos, Map.find !stop_states ticker, get_price ticker)
  with
  | Position.Holding h, Some state, Some bar -> (
      match
        _handle_stop ~config ~pos ~risk_params:h.risk_params ~state ~bar
          ~stop_states ~ticker ~bar_history ~prior_stages
      with
      | Some exit_tr, _ -> (exit_tr :: exits, adjusts)
      | _, Some adj_tr -> (exits, adj_tr :: adjusts)
      | None, None -> (exits, adjusts))
  | _ -> (exits, adjusts)

(** Update stops for all held positions. Returns (exit_transitions,
    adjust_transitions). *)
let _update_stops ~config ~positions ~get_price ~stop_states ~bar_history
    ~prior_stages =
  Map.fold positions ~init:([], []) ~f:(fun ~key:ticker ~data:pos acc ->
      _process_stop ~config ~stop_states ~get_price ~bar_history ~prior_stages
        ticker pos acc)

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
      _weekly_bars_for ~bar_history ~symbol:ticker ~n:config.lookback_bars
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

let _on_market_close ~config ~stop_states ~prior_macro ~bar_history
    ~prior_stages ~get_price ~get_indicator:_ ~(portfolio : Portfolio_view.t) =
  let positions = portfolio.positions in
  let all_symbols = config.index_symbol :: config.universe in
  _accumulate_bars ~bar_history ~get_price ~symbols:all_symbols;
  let current_date =
    match get_price config.index_symbol with
    | Some bar -> bar.Types.Daily_price.date
    | None -> Date.today ~zone:Time_float.Zone.utc
  in
  let exit_transitions, adjust_transitions =
    _update_stops ~config ~positions ~get_price ~stop_states ~bar_history
      ~prior_stages
  in
  let index_bars =
    _weekly_bars_for ~bar_history ~symbol:config.index_symbol
      ~n:config.lookback_bars
  in
  let entry_transitions =
    if not (_is_screening_day index_bars) then []
    else
      let index_prior_stage =
        Hashtbl.find prior_stages config.index_symbol
      in
      let macro_result =
        Macro.analyze ~config:config.macro_config ~index_bars ~ad_bars:[]
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

let make ?(initial_stop_states = String.Map.empty) config =
  let stop_states = ref initial_stop_states in
  let prior_macro : Weinstein_types.market_trend ref =
    ref Weinstein_types.Neutral
  in
  let bar_history : Types.Daily_price.t list Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let module M = struct
    let name = name

    let on_market_close =
      _on_market_close ~config ~stop_states ~prior_macro ~bar_history
        ~prior_stages
  end in
  (module M : Strategy_interface.STRATEGY)
