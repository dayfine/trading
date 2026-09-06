(** Applies simulator-side forced exits — see [forced_exit.mli]. *)

open Core
module Position = Trading_strategy.Position

type request = {
  symbol : string;
  signed_quantity : float;
  exit_price : float;
  reason : Position.exit_reason;
  id_tag : string;
}

type outcome = {
  portfolio : Trading_portfolio.Portfolio.t;
  positions : Position.t String.Map.t;
  trades : Trading_base.Types.trade list;
  transitions : Position.transition list;
}

(* Commission for the synthetic trade, computed the same way the engine computes
   fill commission: max(per_share * quantity, minimum). *)
let _commission ~(commission : Trading_engine.Types.commission_config) ~quantity
    =
  Float.max (commission.per_share *. quantity) commission.minimum

(* Build the synthetic market trade that flattens [r]. A long
   ([signed_quantity > 0]) is closed with a Sell; a short with a Buy. *)
let _exit_trade ~date ~commission (r : request) : Trading_base.Types.trade =
  let qty = Float.abs r.signed_quantity in
  let side =
    if Float.( > ) r.signed_quantity 0.0 then Trading_base.Types.Sell
    else Trading_base.Types.Buy
  in
  {
    id = sprintf "%s-%s-%s" r.symbol r.id_tag (Date.to_string date);
    order_id = sprintf "%s-%s-order-%s" r.symbol r.id_tag (Date.to_string date);
    symbol = r.symbol;
    side;
    quantity = qty;
    price = r.exit_price;
    commission = _commission ~commission ~quantity:qty;
    timestamp =
      Time_ns_unix.of_date_ofday ~zone:Time_float.Zone.utc date
        Time_ns_unix.Ofday.start_of_day;
  }

(* The Holding strategy position for [symbol], if any. *)
let _find_holding positions symbol =
  Map.to_alist positions
  |> List.find ~f:(fun (_, pos) ->
      String.equal pos.Position.symbol symbol
      &&
      match Position.get_state pos with
      | Position.Holding _ -> true
      | _ -> false)

(* Install [data] in [acc], or remove [key] when the position is Closed (Closed
   positions are strategy-invisible; audit trails live elsewhere). *)
let _set_or_drop_if_closed acc ~key ~data =
  if Position.is_closed data then Map.remove acc key else Map.set acc ~key ~data

(* The TriggerExit / ExitFill / ExitComplete triple that closes Holding [pos]
   (id [id]) at [exit_price]. Built as data rather than applied inline so the
   same list can be both folded onto the position AND reported to the caller's
   transition observer — the [Stop_log] path that puts [exit_reason]'s label in
   [trades.csv] (#2687). *)
let _close_transitions ~id ~date ~exit_price ~exit_reason pos =
  let open Position in
  let qty = match get_state pos with Holding h -> h.quantity | _ -> 0.0 in
  [
    { position_id = id; date; kind = TriggerExit { exit_reason; exit_price } };
    {
      position_id = id;
      date;
      kind = ExitFill { filled_quantity = qty; fill_price = exit_price };
    };
    { position_id = id; date; kind = ExitComplete };
  ]

(* Apply [steps] to [pos], returning the closed position, or [None] if any
   transition is rejected. *)
let _drive_holding_to_closed ~steps pos =
  List.fold_result steps ~init:pos ~f:(fun acc trans ->
      Position.apply_transition acc trans)
  |> Result.ok

(* Returns the post-close [positions] paired with the transitions that were
   actually applied — an empty list when there was no Holding position to close
   or the state machine rejected the sequence, so an observer is only ever told
   about exits that really happened. *)
let _close_strategy_position ~date ~exit_price ~exit_reason ~positions symbol =
  match _find_holding positions symbol with
  | None -> (positions, [])
  | Some (id, pos) -> (
      let steps = _close_transitions ~id ~date ~exit_price ~exit_reason pos in
      match _drive_holding_to_closed ~steps pos with
      | Some closed ->
          (_set_or_drop_if_closed positions ~key:id ~data:closed, steps)
      | None -> (positions, []))

(* Apply one request: realise the synthetic trade against the portfolio and
   close the matching strategy position. A trade the portfolio rejects (e.g. the
   position was already flattened) is skipped and not reported. *)
let _apply_one ~date ~commission acc (r : request) =
  let trade = _exit_trade ~date ~commission r in
  match Trading_portfolio.Portfolio.apply_single_trade acc.portfolio trade with
  | Error _ -> acc
  | Ok portfolio ->
      let positions, applied =
        _close_strategy_position ~date ~exit_price:r.exit_price
          ~exit_reason:r.reason ~positions:acc.positions r.symbol
      in
      {
        portfolio;
        positions;
        trades = trade :: acc.trades;
        transitions = List.rev_append applied acc.transitions;
      }

let apply_all ~date ~commission ~portfolio ~positions requests =
  let acc =
    List.fold requests
      ~init:{ portfolio; positions; trades = []; transitions = [] }
      ~f:(_apply_one ~date ~commission)
  in
  {
    acc with
    trades = List.rev acc.trades;
    transitions = List.rev acc.transitions;
  }
