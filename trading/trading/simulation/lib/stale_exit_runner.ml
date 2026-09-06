(** Applies stale/delisted force-exits — see [stale_exit_runner.mli]. *)

open Core
module Position = Trading_strategy.Position

let exit_reason (c : Stale_hold.force_exit) : Position.exit_reason =
  let detail =
    sprintf "last_bar_date=%s days_since_last_bar=%d"
      (Date.to_string c.last_bar_date)
      c.days_since_last_bar
  in
  Position.StrategySignal { label = "stale_force_exit"; detail = Some detail }

let _request_of_candidate (c : Stale_hold.force_exit) : Forced_exit.request =
  {
    symbol = c.symbol;
    signed_quantity = c.signed_quantity;
    exit_price = c.last_close;
    reason = exit_reason c;
    id_tag = "stale-exit";
  }

let tick ~adapter ~config ~commission ~date ~today_bars ?last_known_price
    ~portfolio ~positions () =
  (* Only act on bar-bearing days, matching the detector's false-positive guard:
     a weekend / holiday with no bars at all should not trip a force-exit. *)
  if List.is_empty today_bars then (portfolio, positions, [], [])
  else
    let requests =
      Stale_hold.force_exit_candidates ~adapter ~date ~portfolio ~today_bars
        ?last_known_price ~config ()
      |> List.map ~f:_request_of_candidate
    in
    let out =
      Forced_exit.apply_all ~date ~commission ~portfolio ~positions requests
    in
    (out.portfolio, out.positions, out.trades, out.transitions)
