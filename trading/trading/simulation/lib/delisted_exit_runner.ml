(** Exits held positions at their delisting marker — see
    [delisted_exit_runner.mli]. *)

open Core
module Adapter = Trading_simulation_data.Market_data_adapter
module Position = Trading_strategy.Position

(* The single definition of the delisting token. {!Delisted_ticket_cancel}
   reads it rather than repeating the literal, so the exit half and the cancel
   half of a delisting cannot drift apart in [trade_audit.sexp]. *)
let label = "delisted"

let exit_reason (active_through : Date.t) : Position.exit_reason =
  Position.StrategySignal
    {
      label;
      detail =
        Some (sprintf "active_through=%s" (Date.to_string active_through));
    }

(* The symbol's last REAL close: the marker day's own bar first (the precise
   answer), else the last bar before today. [None] when neither resolves — the
   caller then leaves the position for the stale safety net to flag. *)
let _last_real_close ~adapter ~date ~active_through ~symbol =
  let close (b : Types.Daily_price.t) = b.close_price in
  match Adapter.get_price adapter ~symbol ~date:active_through with
  | Some bar -> Some (close bar)
  | None ->
      Adapter.get_previous_bar adapter ~symbol ~date |> Option.map ~f:close

(* Build the exit request for one held position, or [None] when the symbol has
   no marker, the marker has not passed, the position is flat, or no price
   resolves. *)
let _request_for_position ~adapter ~date ~active_through_for
    (pos : Trading_portfolio.Types.portfolio_position) :
    Forced_exit.request option =
  let%bind.Option active_through = active_through_for pos.symbol in
  if Date.( <= ) date active_through then None
  else
    let signed_quantity =
      Trading_portfolio.Calculations.position_quantity pos
    in
    if Float.equal signed_quantity 0.0 then None
    else
      let%map.Option exit_price =
        _last_real_close ~adapter ~date ~active_through ~symbol:pos.symbol
      in
      {
        Forced_exit.symbol = pos.symbol;
        signed_quantity;
        exit_price;
        reason = exit_reason active_through;
        id_tag = "delisted-exit";
      }

let tick ~adapter ~active_through_for ~commission ~date ~today_bars ~portfolio
    ~positions () =
  (* Only act on bar-bearing days, matching {!Stale_exit_runner}: a weekend /
     holiday with no bars at all should not trip an exit. *)
  if List.is_empty today_bars then (portfolio, positions, [], [])
  else
    let requests =
      List.filter_map portfolio.Trading_portfolio.Portfolio.positions
        ~f:(_request_for_position ~adapter ~date ~active_through_for)
    in
    let out =
      Forced_exit.apply_all ~date ~commission ~portfolio ~positions requests
    in
    (out.portfolio, out.positions, out.trades, out.transitions)
