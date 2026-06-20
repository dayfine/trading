open Core
open Types

let effective_min_stop_distance_pct ~(config : Stop_types.config)
    ~base_min_distance_pct ~entry_price ~(bars : Daily_price.t list) =
  if Float.( <= ) config.vol_scaled_stop_atr_mult 0.0 then base_min_distance_pct
  else if Float.( <= ) entry_price 0.0 then base_min_distance_pct
  else
    match Atr.atr ~period:config.vol_scaled_stop_atr_period bars with
    | None -> base_min_distance_pct
    | Some atr when Float.( <= ) atr 0.0 -> base_min_distance_pct
    | Some atr ->
        let atr_pct = atr /. entry_price in
        Float.max base_min_distance_pct
          (config.vol_scaled_stop_atr_mult *. atr_pct)
