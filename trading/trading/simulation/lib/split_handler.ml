open Core

(* #3173: with no guard the detected factor passes through unchanged. *)
let _guard split_guard ~symbol ~date ~(prev : Types.Daily_price.t) detected =
  match split_guard with
  | None -> detected
  | Some guard ->
      Split_dividend_guard.filter guard ~symbol ~date
        ~prev_close:prev.close_price detected

let detect_for_symbol ?split_guard ~adapter ~date ~symbol () =
  let curr =
    Trading_simulation_data.Market_data_adapter.get_price adapter ~symbol ~date
  in
  let prev =
    Trading_simulation_data.Market_data_adapter.get_previous_bar adapter ~symbol
      ~date
  in
  let%bind.Option curr = curr in
  let%bind.Option prev = prev in
  let detected = Types.Split_detector.detect_split ~prev ~curr () in
  let%map.Option factor = _guard split_guard ~symbol ~date ~prev detected in
  { Trading_portfolio.Split_event.symbol; date; factor }

let detect_for_held_positions ?split_guard ~adapter ~date ~portfolio () =
  List.filter_map portfolio.Trading_portfolio.Portfolio.positions
    ~f:(fun (pos : Trading_portfolio.Types.portfolio_position) ->
      detect_for_symbol ?split_guard ~adapter ~date ~symbol:pos.symbol ())

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

let detect_and_apply ?split_guard ~adapter ~date ~portfolio ~positions () =
  let events =
    detect_for_held_positions ?split_guard ~adapter ~date ~portfolio ()
  in
  (apply_events portfolio events, apply_to_positions positions events, events)
