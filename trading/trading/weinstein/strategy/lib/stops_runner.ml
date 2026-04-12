open Core
open Trading_strategy

(** Compute MA direction and value for a symbol from its accumulated bar
    history. Reads and updates [prior_stages] so Stage1->Stage2 transition
    detection works across calls. Returns [(Flat, close_price)] when there
    aren't enough bars yet for the MA. *)
let _compute_ma ~(stage_config : Stage.config) ~lookback_bars ~bar_history
    ~prior_stages ~symbol ~fallback_price =
  let weekly =
    Bar_history.weekly_bars_for bar_history ~symbol ~n:lookback_bars
  in
  if List.length weekly < stage_config.ma_period then
    (Weinstein_types.Flat, fallback_price)
  else
    let prior_stage = Hashtbl.find prior_stages symbol in
    let result =
      Stage.classify ~config:stage_config ~bars:weekly ~prior_stage
    in
    Hashtbl.set prior_stages ~key:symbol ~data:result.stage;
    (result.ma_direction, result.ma_value)

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
let _handle_stop ~stops_config ~stage_config ~lookback_bars ~(pos : Position.t)
    ~(risk_params : Position.risk_params) ~state ~bar ~stop_states ~ticker
    ~bar_history ~prior_stages =
  let current_date = bar.Types.Daily_price.date in
  let ma_direction, ma_value =
    _compute_ma ~stage_config ~lookback_bars ~bar_history ~prior_stages
      ~symbol:ticker ~fallback_price:bar.Types.Daily_price.close_price
  in
  let new_state, event =
    Weinstein_stops.update ~config:stops_config ~side:pos.Position.side ~state
      ~current_bar:bar ~ma_value ~ma_direction
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
let _process_stop ~stops_config ~stage_config ~lookback_bars ~stop_states
    ~get_price ~bar_history ~prior_stages (pos : Position.t) (exits, adjusts) =
  let ticker = pos.symbol in
  match
    (Position.get_state pos, Map.find !stop_states ticker, get_price ticker)
  with
  | Position.Holding h, Some state, Some bar -> (
      match
        _handle_stop ~stops_config ~stage_config ~lookback_bars ~pos
          ~risk_params:h.risk_params ~state ~bar ~stop_states ~ticker
          ~bar_history ~prior_stages
      with
      | Some exit_tr, _ -> (exit_tr :: exits, adjusts)
      | _, Some adj_tr -> (exits, adj_tr :: adjusts)
      | None, None -> (exits, adjusts))
  | _ -> (exits, adjusts)

let update ~stops_config ~stage_config ~lookback_bars ~positions ~get_price
    ~stop_states ~bar_history ~prior_stages =
  Map.fold positions ~init:([], []) ~f:(fun ~key:_ ~data:pos acc ->
      _process_stop ~stops_config ~stage_config ~lookback_bars ~stop_states
        ~get_price ~bar_history ~prior_stages pos acc)
