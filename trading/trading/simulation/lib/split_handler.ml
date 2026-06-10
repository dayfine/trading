open Core

let detect_for_symbol ~adapter ~date ~symbol =
  let curr =
    Trading_simulation_data.Market_data_adapter.get_price adapter ~symbol ~date
  in
  let prev =
    Trading_simulation_data.Market_data_adapter.get_previous_bar adapter ~symbol
      ~date
  in
  let%bind.Option curr = curr in
  let%bind.Option prev = prev in
  let%map.Option factor = Types.Split_detector.detect_split ~prev ~curr () in
  { Trading_portfolio.Split_event.symbol; date; factor }

let detect_for_held_positions ~adapter ~date ~portfolio =
  List.filter_map portfolio.Trading_portfolio.Portfolio.positions
    ~f:(fun (pos : Trading_portfolio.Types.portfolio_position) ->
      detect_for_symbol ~adapter ~date ~symbol:pos.symbol)

let apply_events portfolio events =
  List.fold events ~init:portfolio ~f:(fun acc event ->
      Trading_portfolio.Split_event.apply_to_portfolio event acc)

let _scale_holding_state factor quantity entry_price entry_date risk_params =
  Trading_strategy.Position.Holding
    {
      quantity = quantity *. factor;
      entry_price = entry_price /. factor;
      entry_date;
      risk_params;
    }

let _scale_exiting_state factor quantity entry_price entry_date target_quantity
    exit_price filled_quantity started_date risk_params =
  Trading_strategy.Position.Exiting
    {
      quantity = quantity *. factor;
      entry_price = entry_price /. factor;
      entry_date;
      target_quantity = target_quantity *. factor;
      exit_price = exit_price /. factor;
      filled_quantity = filled_quantity *. factor;
      started_date;
      (* [risk_params] left unchanged, mirroring [_scale_holding_state]. *)
      risk_params;
    }

let _compute_scaled_state factor
    (state : Trading_strategy.Position.position_state) :
    Trading_strategy.Position.position_state =
  let open Trading_strategy.Position in
  match state with
  | Holding { quantity; entry_price; entry_date; risk_params } ->
      _scale_holding_state factor quantity entry_price entry_date risk_params
  | Exiting
      {
        quantity;
        entry_price;
        entry_date;
        target_quantity;
        exit_price;
        filled_quantity;
        started_date;
        risk_params;
      } ->
      _scale_exiting_state factor quantity entry_price entry_date
        target_quantity exit_price filled_quantity started_date risk_params
  | (Entering _ | Closed _) as s -> s

let apply_to_position (factor : float) (pos : Trading_strategy.Position.t) :
    Trading_strategy.Position.t =
  { pos with state = _compute_scaled_state factor pos.state }

let _apply_event_to_position (event : Trading_portfolio.Split_event.t)
    (pos : Trading_strategy.Position.t) : Trading_strategy.Position.t =
  if String.equal pos.Trading_strategy.Position.symbol event.symbol then
    apply_to_position event.factor pos
  else pos

let apply_to_positions (positions : Trading_strategy.Position.t String.Map.t)
    (events : Trading_portfolio.Split_event.t list) :
    Trading_strategy.Position.t String.Map.t =
  List.fold events ~init:positions ~f:(fun acc event ->
      Map.map acc ~f:(_apply_event_to_position event))
