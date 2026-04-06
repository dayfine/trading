open Core
open Trading_strategy

type config = {
  universe : string list;
  index_symbol : string;
  stage : Stage.config;
  macro : Macro.config;
  screening : Screener.config;
  portfolio : Portfolio_risk.config;
  stops : Weinstein_stops.config;
  initial_stop_buffer : float;
  lookback_bars : int;
}

let default_config ~universe ~index_symbol =
  {
    universe;
    index_symbol;
    stage = Stage.default_config;
    macro = Macro.default_config;
    screening = Screener.default_config;
    portfolio = Portfolio_risk.default_config;
    stops = Weinstein_stops.default_config;
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

(* Collect available bars for a symbol via the price accessor.
   The strategy interface provides only the current bar — full history is not
   yet accessible through get_price. Returns the single current bar if
   available. Stage and macro analysers degrade gracefully when bar history is
   short (< 30 bars). *)

(** Collect weekly bars for a symbol from the price adapter. *)
let _collect_bars ~(get_price : Strategy_interface.get_price_fn)
    ~(get_indicator : Strategy_interface.get_indicator_fn) ~symbol ~(n : int) :
    Types.Daily_price.t list =
  ignore (get_indicator, n);
  match get_price symbol with Some bar -> [ bar ] | None -> []

let _make_exit_transition ~(pos : Position.t) ~current_date ~state ~bar =
  {
    Position.position_id = pos.id;
    date = current_date;
    kind =
      Position.TriggerExit
        {
          exit_reason =
            Position.StopLoss
              {
                stop_price = Weinstein_stops.get_stop_level state;
                actual_price = bar.Types.Daily_price.low_price;
                loss_percent = 0.0;
              };
          exit_price = bar.Types.Daily_price.low_price;
        };
  }

let _make_adjust_transition ~(pos : Position.t) ~current_date
    ~(risk_params : Position.risk_params) ~new_level =
  {
    Position.position_id = pos.id;
    date = current_date;
    kind =
      Position.UpdateRiskParams
        {
          new_risk_params =
            {
              Position.stop_loss_price = Some new_level;
              take_profit_price = risk_params.take_profit_price;
              max_hold_days = risk_params.max_hold_days;
            };
        };
  }

(** Update stops for held positions. Returns (exit_transitions,
    adjust_transitions). *)
let _update_stops ~config ~positions ~get_price ~stop_states =
  Map.fold positions ~init:([], [])
    ~f:(fun ~key:ticker ~data:pos (exits, adjusts) ->
      match Position.get_state pos with
      | Position.Holding h -> (
          match (Map.find !stop_states ticker, get_price ticker) with
          | None, _ | _, None -> (exits, adjusts)
          | Some state, Some bar -> (
              let current_date = bar.Types.Daily_price.date in
              (* Use Flat as conservative MA direction placeholder — will use computed slope
                 when we have full weekly bar history. *)
              let new_state, event =
                Weinstein_stops.update ~config:config.stops
                  ~side:pos.Position.side ~state ~current_bar:bar
                  ~ma_value:bar.close_price ~ma_direction:Weinstein_types.Flat
                  ~stage:
                    (Weinstein_types.Stage2
                       { weeks_advancing = 1; late = false })
              in
              stop_states := Map.set !stop_states ~key:ticker ~data:new_state;
              match event with
              | Weinstein_stops.Stop_hit _ ->
                  let tr =
                    _make_exit_transition ~pos ~current_date ~state ~bar
                  in
                  (tr :: exits, adjusts)
              | Weinstein_stops.Stop_raised { new_level; _ } ->
                  let tr =
                    _make_adjust_transition ~pos ~current_date
                      ~risk_params:h.risk_params ~new_level
                  in
                  (exits, tr :: adjusts)
              | _ -> (exits, adjusts)))
      | _ -> (exits, adjusts))

(** Generate CreateEntering transitions for top screener candidates. *)
let _entries_from_candidates ~config ~candidates ~stop_states ~positions =
  let held = Map.keys positions in
  let snapshot =
    Portfolio_risk.snapshot ~cash:0.0 ~positions:[] ()
    (* Placeholder — real snapshot requires portfolio value *)
  in
  List.filter_map candidates ~f:(fun (cand : Screener.scored_candidate) ->
      if List.mem held cand.ticker ~equal:String.equal then None
      else
        let sizing =
          Portfolio_risk.compute_position_size ~config:config.portfolio
            ~portfolio_value:snapshot.total_value
            ~entry_price:cand.suggested_entry ~stop_price:cand.suggested_stop ()
        in
        if sizing.shares = 0 then None
        else
          let id = _gen_position_id cand.ticker in
          let initial_stop =
            Weinstein_stops.compute_initial_stop ~config:config.stops
              ~side:Trading_base.Types.Long
              ~reference_level:
                (cand.suggested_stop *. config.initial_stop_buffer)
          in
          stop_states :=
            Map.set !stop_states ~key:cand.ticker ~data:initial_stop;
          Some
            {
              Position.position_id = id;
              date = Date.today ~zone:Time_float.Zone.utc;
              kind =
                Position.CreateEntering
                  {
                    symbol = cand.ticker;
                    side = Trading_base.Types.Long;
                    target_quantity = Float.of_int sizing.shares;
                    entry_price = cand.suggested_entry;
                    reasoning =
                      Position.ManualDecision
                        {
                          description =
                            Printf.sprintf "Weinstein %s: %s"
                              (Weinstein_types.grade_to_string cand.grade)
                              (String.concat ~sep:"; " cand.rationale);
                        };
                  };
            })

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
    Screener.screen ~config:config.screening ~macro_trend ~sector_map ~stocks
      ~held_tickers:(Map.keys positions)
  in
  _entries_from_candidates ~config
    ~candidates:screen_result.Screener.buy_candidates ~stop_states ~positions

(* ------------------------------------------------------------------ *)
(* make                                                                  *)
(* ------------------------------------------------------------------ *)

let make config =
  let stop_states : Weinstein_stops.stop_state String.Map.t ref =
    ref String.Map.empty
  in
  let prior_macro : Weinstein_types.market_trend ref =
    ref Weinstein_types.Neutral
  in
  let module M = struct
    let name = name

    let on_market_close ~get_price ~get_indicator ~positions =
      let exit_transitions, adjust_transitions =
        _update_stops ~config ~positions ~get_price ~stop_states
      in
      let index_bars =
        _collect_bars ~get_price ~get_indicator ~symbol:config.index_symbol
          ~n:config.lookback_bars
      in
      let macro_result =
        Macro.analyze ~config:config.macro ~index_bars ~ad_bars:[]
          ~global_index_bars:[] ~prior_stage:None ~prior:None
      in
      prior_macro := macro_result.trend;
      let entry_transitions =
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
  end in
  (module M : Strategy_interface.STRATEGY)
