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

let _exit_reason (c : Stale_hold.force_exit) : Position.exit_reason =
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

(* Drive the strategy [Position.t] for [symbol] from Holding through Exiting to
   Closed at [exit_price], then drop it from [positions]. Returns [positions]
   unchanged when no Holding position for [symbol] exists (the portfolio is the
   source of truth for the realised trade; the strategy map is best-effort kept
   in sync). *)
let _close_strategy_position ~date ~exit_price ~exit_reason ~positions symbol =
  match _find_holding positions symbol with
  | None -> positions
  | Some (id, pos) -> (
      let open Position in
      let qty = match get_state pos with Holding h -> h.quantity | _ -> 0.0 in
      let steps =
        [
          {
            position_id = id;
            date;
            kind = TriggerExit { exit_reason; exit_price };
          };
          {
            position_id = id;
            date;
            kind = ExitFill { filled_quantity = qty; fill_price = exit_price };
          };
          { position_id = id; date; kind = ExitComplete };
        ]
      in
      match
        List.fold_result steps ~init:pos ~f:(fun acc trans ->
            apply_transition acc trans)
      with
      | Ok closed -> _set_or_drop_if_closed positions ~key:id ~data:closed
      | Error _ -> positions)

(* Apply one stale force-exit: realise the synthetic trade against the portfolio
   and close the matching strategy position. A trade the portfolio rejects (e.g.
   the position was already flattened) is skipped and not reported. *)
let _apply_one ~date ~commission (portfolio, positions, trades)
    (c : Stale_hold.force_exit) =
  let trade = _exit_trade ~date ~commission c in
  match Trading_portfolio.Portfolio.apply_single_trade portfolio trade with
  | Error _ -> (portfolio, positions, trades)
  | Ok portfolio ->
      let positions =
        _close_strategy_position ~date ~exit_price:c.last_close
          ~exit_reason:(_exit_reason c) ~positions c.symbol
      in
      (portfolio, positions, trade :: trades)

let tick ~adapter ~config ~commission ~date ~today_bars ~portfolio ~positions =
  (* Only act on bar-bearing days, matching the detector's false-positive guard:
     a weekend / holiday with no bars at all should not trip a force-exit. *)
  if List.is_empty today_bars then (portfolio, positions, [])
  else
    let candidates =
      Stale_hold.force_exit_candidates ~adapter ~date ~portfolio ~today_bars
        ~config
    in
    let portfolio, positions, trades_rev =
      List.fold candidates ~init:(portfolio, positions, [])
        ~f:(_apply_one ~date ~commission)
    in
    (portfolio, positions, List.rev trades_rev)
