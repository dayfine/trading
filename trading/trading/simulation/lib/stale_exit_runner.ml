(** Applies stale/delisted force-exits — see [stale_exit_runner.mli]. *)

open Core
module Position = Trading_strategy.Position

(* Commission for the synthetic stale-exit trade, computed the same way the
   engine computes fill commission: max(per_share * quantity, minimum). *)
let _commission ~(commission : Trading_engine.Types.commission_config) ~quantity
    =
  Float.max (commission.per_share *. quantity) commission.minimum

(* Build the synthetic market trade that flattens a stale force-exit candidate.
   A long ([signed_quantity > 0]) is closed with a Sell; a short with a Buy. The
   fill price is the candidate's last available close — there is no bar today, so
   this is the only meaningful market price. *)
let _exit_trade ~date ~commission (c : Stale_hold.force_exit) :
    Trading_base.Types.trade =
  let qty = Float.abs c.signed_quantity in
  let side =
    if Float.( > ) c.signed_quantity 0.0 then Trading_base.Types.Sell
    else Trading_base.Types.Buy
  in
  {
    id = sprintf "%s-stale-exit-%s" c.symbol (Date.to_string date);
    order_id = sprintf "%s-stale-exit-order-%s" c.symbol (Date.to_string date);
    symbol = c.symbol;
    side;
    quantity = qty;
    price = c.last_close;
    commission = _commission ~commission ~quantity:qty;
    timestamp =
      Time_ns_unix.of_date_ofday ~zone:Time_float.Zone.utc date
        Time_ns_unix.Ofday.start_of_day;
  }

let exit_reason (c : Stale_hold.force_exit) : Position.exit_reason =
  let detail =
    sprintf "last_bar_date=%s days_since_last_bar=%d"
      (Date.to_string c.last_bar_date)
      c.days_since_last_bar
  in
  Position.StrategySignal { label = "stale_force_exit"; detail = Some detail }

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

(* Apply one stale force-exit: realise the synthetic trade against the portfolio
   and close the matching strategy position. A trade the portfolio rejects (e.g.
   the position was already flattened) is skipped and not reported. *)
let _apply_one ~date ~commission (portfolio, positions, trades, transitions)
    (c : Stale_hold.force_exit) =
  let trade = _exit_trade ~date ~commission c in
  match Trading_portfolio.Portfolio.apply_single_trade portfolio trade with
  | Error _ -> (portfolio, positions, trades, transitions)
  | Ok portfolio ->
      let positions, applied =
        _close_strategy_position ~date ~exit_price:c.last_close
          ~exit_reason:(exit_reason c) ~positions c.symbol
      in
      ( portfolio,
        positions,
        trade :: trades,
        List.rev_append applied transitions )

let tick ~adapter ~config ~commission ~date ~today_bars ?last_known_price
    ~portfolio ~positions () =
  (* Only act on bar-bearing days, matching the detector's false-positive guard:
     a weekend / holiday with no bars at all should not trip a force-exit. *)
  if List.is_empty today_bars then (portfolio, positions, [], [])
  else
    let candidates =
      Stale_hold.force_exit_candidates ~adapter ~date ~portfolio ~today_bars
        ?last_known_price ~config ()
    in
    let portfolio, positions, trades_rev, transitions_rev =
      List.fold candidates
        ~init:(portfolio, positions, [], [])
        ~f:(_apply_one ~date ~commission)
    in
    (portfolio, positions, List.rev trades_rev, List.rev transitions_rev)
