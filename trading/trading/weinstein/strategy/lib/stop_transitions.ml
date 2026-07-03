(** Position transitions emitted by the stops pass. See .mli. *)

open Trading_strategy

let trigger_fill_price ?(on_close = false)
    ~(side : Trading_base.Types.position_side) ~bar () =
  if on_close then bar.Types.Daily_price.close_price
  else
    match side with
    | Long -> bar.Types.Daily_price.low_price
    | Short -> bar.Types.Daily_price.high_price

let make_exit_transition ?(on_close = false) ~(pos : Position.t) ~current_date
    ~state ~bar () =
  let actual_price =
    trigger_fill_price ~on_close ~side:pos.Position.side ~bar ()
  in
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

let make_adjust_transition ~(pos : Position.t) ~current_date
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

let handle_trigger_only ~on_close ~(pos : Position.t) ~state ~bar ~current_date
    =
  if
    Weinstein_stops.check_stop_hit ~on_close ~state ~side:pos.Position.side ~bar
      ()
  then
    ( Some (make_exit_transition ~on_close ~pos ~current_date ~state ~bar ()),
      None )
  else (None, None)

let of_stop_event ~on_close ~(pos : Position.t)
    ~(risk_params : Position.risk_params) ~state ~bar ~current_date ~event =
  match event with
  | Weinstein_stops.Stop_hit _ ->
      ( Some (make_exit_transition ~on_close ~pos ~current_date ~state ~bar ()),
        None )
  | Weinstein_stops.Stop_raised { new_level; _ } ->
      ( None,
        Some (make_adjust_transition ~pos ~current_date ~risk_params ~new_level)
      )
  | _ -> (None, None)
