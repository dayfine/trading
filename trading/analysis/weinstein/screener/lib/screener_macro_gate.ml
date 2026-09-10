(** The cascade's macro gate. See [screener_macro_gate.mli]. *)

open Weinstein_types

let longs_admitted_by_macro ~neutral_blocks_longs macro_trend =
  match macro_trend with
  | Bearish -> false
  | Neutral -> not neutral_blocks_longs
  | Bullish -> true

let shorts_admitted_by_macro ~neutral_blocks_shorts macro_trend =
  match macro_trend with
  | Bullish -> false
  | Neutral -> not neutral_blocks_shorts
  | Bearish -> true

let longs_admitted_by_breadth ~neutral_blocks_longs ~deteriorating_blocks_longs
    (breadth_state : breadth_state) =
  longs_admitted_by_macro ~neutral_blocks_longs
    (market_trend_of_breadth_state breadth_state)
  &&
  match breadth_state with
  | Deteriorating -> not deteriorating_blocks_longs
  | Bullish_breadth | Neutral_breadth | Recovering | Bearish_breadth -> true

let breadth_state_or_projection ~macro_trend = function
  | Some state -> state
  | None -> breadth_state_of_market_trend macro_trend
