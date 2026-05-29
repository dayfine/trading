open Core
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

type t =
  | Stage3_exit
  | Stage1_cover_short
  | End_of_period
  | Stop_out
  | Stage4_decline
  | Laggard_rotation
[@@deriving show, eq, sexp]

let derive ~final_bar_date ~(trade : Walk_step.trade) =
  if Date.equal trade.exit_date final_bar_date then End_of_period
  else
    match trade.variant_side with
    | `Long -> Stage3_exit
    | `Short -> Stage1_cover_short
