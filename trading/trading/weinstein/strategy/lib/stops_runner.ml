open Core
open Trading_strategy

(** Position-favourable stage + MA direction default for warmup periods (when
    fewer than [stage_config.ma_period] weekly bars are available). The return
    must drive {!Weinstein_stops.update} into a no-tighten branch:

    - {!Weinstein_stops._should_tighten_long} tightens on Stage 3 / Stage 4 and
      on Stage 2 + Flat-or-Declining MA (when [tighten_on_flat_ma] is true). The
      only no-tighten branch for a long is Stage 2 + Rising MA.
    - {!Weinstein_stops._should_tighten_short} tightens on Stage 1 / Stage 2 and
      on Stage 4 + Rising-or-Flat MA. The only no-tighten branch for a short is
      Stage 4 + Declining MA.

    Returning a position-favourable warmup default avoids the G1 short-stop
    pathology (see [dev/notes/short-side-gaps-2026-04-29.md]): hardcoding
    [Stage2 + Flat] for shorts triggered tightening on every warmup tick,
    dragging short stops below entry within one or two bars. *)
let _default_stage_and_ma_for_side = function
  | Trading_base.Types.Long ->
      ( Weinstein_types.Stage2 { weeks_advancing = 1; late = false },
        Weinstein_types.Rising )
  | Trading_base.Types.Short ->
      (Weinstein_types.Stage4 { weeks_declining = 1 }, Weinstein_types.Declining)

(** Compute MA direction, value, and stage for a symbol via panel-shaped
    callbacks. Reads and updates [prior_stages] so Stage1->Stage2 transition
    detection works across calls. Returns [(Flat, fallback_price, default)]
    where [default] is [_default_stage_and_ma_for_side ~side] when there aren't
    enough weekly bars yet for the MA — see G1 fix in
    [dev/notes/short-side-gaps-2026-04-29.md]: hardcoding [Stage2] for shorts
    triggered spurious tightening on every warmup tick, dragging short stops
    below entry. The position-favourable default keeps the state machine in its
    initial pose during warmup.

    Stage 4 PR-A: this no longer materialises a {!Daily_price.t list}. The
    weekly view is read directly from panels and threaded into a
    {!Stage.callbacks} bundle.

    Stage 4 PR-D: an optional [ma_cache] threads through to the panel callbacks.
    Mid-week stop adjustments miss the cache (Friday-aligned only) and fall back
    to inline; Friday-aligned calls hit the cache. *)
let _compute_ma_and_stage ?ma_cache ~(stage_config : Stage.config)
    ~lookback_bars ~bar_reader ~as_of ~prior_stages ~symbol ~side
    ~fallback_price () =
  let weekly =
    Bar_reader.weekly_view_for bar_reader ~symbol ~n:lookback_bars ~as_of
  in
  if weekly.n < stage_config.ma_period then
    let stage, ma_direction = _default_stage_and_ma_for_side side in
    (ma_direction, fallback_price, stage)
  else
    let prior_stage = Hashtbl.find prior_stages symbol in
    let callbacks =
      Panel_callbacks.stage_callbacks_of_weekly_view ?ma_cache ~symbol
        ~config:stage_config ~weekly ()
    in
    let result =
      Stage.classify_with_callbacks ~config:stage_config
        ~get_ma:callbacks.get_ma ~get_close:callbacks.get_close ~prior_stage
    in
    Hashtbl.set prior_stages ~key:symbol ~data:result.stage;
    (result.ma_direction, result.ma_value, result.stage)

(** Worst-case fill price when a stop trigger fires.

    For a long, the stop fires when the bar's low crosses DOWN through the stop
    level — the worst-case fill is at the bar's low (maximum slippage in the
    loss direction). For a short, the stop fires when the bar's high crosses UP
    through the stop level — the worst-case fill is at the bar's high (maximum
    slippage on the cover).

    Pre-G1-fix this function unconditionally returned [bar.low_price], which for
    shorts produced audit-log entries like ALB 2019-01-29 (stop $103.58,
    actual_price $77.49 when bar low was $76) that read as if the stop fired
    against profitable territory — the recorded actual price was the bar low,
    not the trigger price near the high. See G1 in
    [dev/notes/short-side-gaps-2026-04-29.md]. *)
let _trigger_fill_price ~(side : Trading_base.Types.position_side) ~bar =
  match side with
  | Long -> bar.Types.Daily_price.low_price
  | Short -> bar.Types.Daily_price.high_price

let _make_exit_transition ~(pos : Position.t) ~current_date ~state ~bar =
  let actual_price = _trigger_fill_price ~side:pos.Position.side ~bar in
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
let _handle_stop ?ma_cache ~stops_config ~stage_config ~lookback_bars
    ~(pos : Position.t) ~(risk_params : Position.risk_params) ~state ~bar
    ~stop_states ~ticker ~bar_reader ~as_of ~prior_stages () =
  let current_date = bar.Types.Daily_price.date in
  let ma_direction, ma_value, stage =
    _compute_ma_and_stage ?ma_cache ~stage_config ~lookback_bars ~bar_reader
      ~as_of ~prior_stages ~symbol:ticker ~side:pos.Position.side
      ~fallback_price:bar.Types.Daily_price.close_price ()
  in
  let new_state, event =
    Weinstein_stops.update ~config:stops_config ~side:pos.Position.side ~state
      ~current_bar:bar ~ma_value ~ma_direction ~stage
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
let _process_stop ?ma_cache ~stops_config ~stage_config ~lookback_bars
    ~stop_states ~get_price ~bar_reader ~as_of ~prior_stages (pos : Position.t)
    (exits, adjusts) =
  let ticker = pos.symbol in
  match
    (Position.get_state pos, Map.find !stop_states ticker, get_price ticker)
  with
  | Position.Holding h, Some state, Some bar -> (
      match
        _handle_stop ?ma_cache ~stops_config ~stage_config ~lookback_bars ~pos
          ~risk_params:h.risk_params ~state ~bar ~stop_states ~ticker
          ~bar_reader ~as_of ~prior_stages ()
      with
      | Some exit_tr, _ -> (exit_tr :: exits, adjusts)
      | _, Some adj_tr -> (exits, adj_tr :: adjusts)
      | None, None -> (exits, adjusts))
  | _ -> (exits, adjusts)

let update ?ma_cache ~stops_config ~stage_config ~lookback_bars ~positions
    ~get_price ~stop_states ~bar_reader ~as_of ~prior_stages () =
  Map.fold positions ~init:([], []) ~f:(fun ~key:_ ~data:pos acc ->
      _process_stop ?ma_cache ~stops_config ~stage_config ~lookback_bars
        ~stop_states ~get_price ~bar_reader ~as_of ~prior_stages pos acc)
