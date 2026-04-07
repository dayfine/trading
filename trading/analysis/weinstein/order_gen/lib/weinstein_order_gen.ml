open Core
open Trading_base.Types

type suggested_order = {
  ticker : string;
  side : side;
  order_type : order_type;
  shares : int;
  grade : Weinstein_types.grade option;
  rationale : string list;
}
[@@deriving show, eq]

(* Determine order side for closing a position based on position side. *)
let _exit_side (position : Trading_strategy.Position.t) =
  match position.side with Long -> Sell | Short -> Buy

(* Extract quantity from holding state. Returns 0 for non-holding positions. *)
let _holding_quantity (position : Trading_strategy.Position.t) =
  match Trading_strategy.Position.get_state position with
  | Trading_strategy.Position.Holding h -> Float.to_int h.quantity
  | _ -> 0

let _make_entry_order (candidate : Screener.scored_candidate)
    (sizing : Portfolio_risk.sizing_result) =
  let entry = candidate.suggested_entry in
  {
    ticker = candidate.ticker;
    side = Buy;
    order_type = StopLimit (entry, entry);
    shares = sizing.shares;
    grade = Some candidate.grade;
    rationale = candidate.rationale;
  }

let _compute_sizing (candidate : Screener.scored_candidate) ~portfolio_value
    ~config =
  Portfolio_risk.compute_position_size ~config ~portfolio_value
    ~entry_price:candidate.suggested_entry ~stop_price:candidate.suggested_stop
    ()

let _check_portfolio_limits (candidate : Screener.scored_candidate)
    (sizing : Portfolio_risk.sizing_result) ~snapshot ~config =
  Portfolio_risk.check_limits ~config ~snapshot ~proposed_side:`Long
    ~proposed_value:sizing.position_value
    ~proposed_sector:candidate.sector.Screener.sector_name

let from_candidates ~candidates ~snapshot ~config =
  let portfolio_value = snapshot.Portfolio_risk.total_value in
  List.filter_map candidates ~f:(fun candidate ->
      let sizing = _compute_sizing candidate ~portfolio_value ~config in
      if sizing.shares = 0 then None
      else
        match _check_portfolio_limits candidate sizing ~snapshot ~config with
        | Error _ -> None
        | Ok () -> Some (_make_entry_order candidate sizing))

let _make_stop_order ticker (position : Trading_strategy.Position.t) new_level
    reason =
  let qty = _holding_quantity position in
  if qty = 0 then None
  else
    let side = _exit_side position in
    Some
      {
        ticker;
        side;
        order_type = Stop new_level;
        shares = qty;
        grade = None;
        rationale = [ "Stop raised: " ^ reason ];
      }

let _on_stop_raised ticker positions new_level reason =
  match Map.find positions ticker with
  | None -> None
  | Some position -> _make_stop_order ticker position new_level reason

let from_stop_adjustments ~adjustments ~positions =
  List.filter_map adjustments ~f:(fun (ticker, event) ->
      match event with
      | Weinstein_stops.Stop_raised { old_level = _; new_level; reason } ->
          _on_stop_raised ticker positions new_level reason
      | _ -> None)

let _make_exit_order ticker (position : Trading_strategy.Position.t) =
  let qty = _holding_quantity position in
  if qty = 0 then None
  else
    let side = _exit_side position in
    Some
      {
        ticker;
        side;
        order_type = Market;
        shares = qty;
        grade = None;
        rationale = [ "Stop hit — close position" ];
      }

let _on_stop_hit ticker positions =
  match Map.find positions ticker with
  | None -> None
  | Some position -> _make_exit_order ticker position

let from_exits ~exits ~positions =
  List.filter_map exits ~f:(fun (ticker, event) ->
      match event with
      | Weinstein_stops.Stop_hit _ -> _on_stop_hit ticker positions
      | _ -> None)
