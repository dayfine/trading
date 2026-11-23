open Core
open Weinstein_snapshot
module Gate = Weinstein_strategy.Entry_liquidity_gate

let _warning ~lookback ~(c : Weekly_snapshot.candidate) ~adv ~p =
  sprintf
    "%s dropped: planned position $%.0f exceeds %.2f x %d-day dollar ADV $%.0f \
     (max_entry_adv_participation)"
    c.symbol c.sized_position_value p lookback adv

(* [Ok c] to keep, [Error warning] to drop. *)
let _check ~(liquidity_config : Weinstein_strategy.Liquidity_config.t) ~p reader
    ~as_of (c : Weekly_snapshot.candidate) =
  let dollar_adv =
    Gate.dollar_adv_for ~config:liquidity_config ~bar_reader:reader
      ~current_date:as_of c.symbol
  in
  if
    Gate.participation_allows ~max_participation:(Some p)
      ~position_dollars:c.sized_position_value ~dollar_adv
  then Ok c
  else
    Error
      (_warning ~lookback:liquidity_config.adv_lookback_days ~c
         ~adv:(Option.value dollar_adv ~default:0.0)
         ~p)

let partition ~(liquidity_config : Weinstein_strategy.Liquidity_config.t) reader
    ~as_of candidates =
  match liquidity_config.max_entry_adv_participation with
  | None -> (candidates, [])
  | Some p ->
      List.partition_result
        (List.map candidates ~f:(_check ~liquidity_config ~p reader ~as_of))
