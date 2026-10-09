open Core
module Position = Trading_strategy.Position
module Config = Weinstein_strategy_config

let cancel_reason = "entry_ticket_short_macro_not_bearish"

let _is_resting_short (pos : Position.t) =
  match (pos.side, Position.get_state pos) with
  | Position.Short, Position.Entering { filled_quantity; _ } ->
      Float.equal filled_quantity 0.0
  | _ -> false

let _cancel_transition ~current_date (pos : Position.t) : Position.transition =
  {
    position_id = pos.id;
    date = current_date;
    kind = Position.CancelEntry { reason = cancel_reason };
  }

let macro_cancellations ~positions ~current_date =
  Map.data positions
  |> List.filter ~f:_is_resting_short
  |> List.map ~f:(_cancel_transition ~current_date)

let partition_by_side positions =
  Map.partition_tf positions ~f:(fun (pos : Position.t) ->
      match pos.side with Position.Long -> true | Position.Short -> false)

let armed (config : Config.config) =
  config.enable_entry_ticket_rescreen
  || config.entry_order_max_rest_weeks > 0
  || config.short_cancel_on_non_bearish
  || Option.is_some config.short_entry_order_max_rest_weeks

(* Resting shorts the macro read retires this week, and the positions left for
   the TTL pass. Bearish, or the flag off, retires nothing. *)
let _macro_pass (config : Config.config) ~(macro_result : Macro.result)
    ~positions ~current_date =
  let bearish =
    match macro_result.trend with
    | Weinstein_types.Bearish -> true
    | Weinstein_types.Bullish | Weinstein_types.Neutral -> false
  in
  if bearish || not config.short_cancel_on_non_bearish then ([], positions)
  else
    let cancels = macro_cancellations ~positions ~current_date in
    let gone =
      List.map cancels ~f:(fun (t : Position.transition) -> t.position_id)
      |> String.Set.of_list
    in
    (cancels, Map.filter positions ~f:(fun p -> not (Set.mem gone p.id)))

(* The TTL pass, with the short-only rest-limit override when one is set. *)
let _ttl_pass (config : Config.config) ~pending_entry_e ~positions
    ~still_qualifies ~current_date =
  let run ~max_rest_weeks positions =
    Entry_ticket_ttl.run ~rescreen:config.enable_entry_ticket_rescreen
      ~max_rest_weeks ~pending_entry_e ~positions ~still_qualifies ~current_date
  in
  let long_weeks = config.entry_order_max_rest_weeks in
  match config.short_entry_order_max_rest_weeks with
  | None -> run ~max_rest_weeks:long_weeks positions
  | Some short_weeks ->
      let longs, shorts = partition_by_side positions in
      run ~max_rest_weeks:long_weeks longs
      @ run ~max_rest_weeks:short_weeks shorts

let run config ~macro_result ~pending_entry_e ~positions ~still_qualifies
    ~current_date =
  let macro_cancels, remaining =
    _macro_pass config ~macro_result ~positions ~current_date
  in
  List.iter macro_cancels ~f:(fun (t : Position.transition) ->
      Option.iter (Map.find positions t.position_id) ~f:(fun p ->
          Entry_freeze.release pending_entry_e ~symbol:p.symbol));
  macro_cancels
  @ _ttl_pass config ~pending_entry_e ~positions:remaining ~still_qualifies
      ~current_date
