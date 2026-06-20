open Core
open Weinstein_strategy_config

let min_stop_distance_for ~config ~bar_reader ~current_date
    (cand : Screener.scored_candidate) =
  let base = config.screening_config.candidate_params.installed_stop_min_pct in
  if Float.( <= ) config.stops_config.vol_scaled_stop_atr_mult 0.0 then base
  else
    let bars =
      Bar_reader.daily_bars_for bar_reader ~symbol:cand.ticker
        ~as_of:current_date
    in
    let entry_price =
      match List.last bars with
      | Some bar -> bar.Types.Daily_price.close_price
      | None -> cand.suggested_entry
    in
    Weinstein_stops.Vol_scaled_stop.effective_min_stop_distance_pct
      ~config:config.stops_config ~base_min_distance_pct:base ~entry_price ~bars
