open Core
open Types
open Weinstein_types

type config = {
  lookback_weeks : int;
  strong_threshold : float;
  adequate_threshold : float;
  pullback_contraction : float;
}

let default_config =
  {
    lookback_weeks = 4;
    strong_threshold = 2.0;
    adequate_threshold = 1.5;
    pullback_contraction = 0.25;
  }

type result = {
  confirmation : volume_confirmation;
  event_volume : int;
  avg_volume : float;
  volume_ratio : float;
}

let average_volume ~bars ~n : float =
  if n <= 0 || List.is_empty bars then 0.0
  else
    let take_last =
      List.rev bars |> fun l -> List.sub l ~pos:0 ~len:(min n (List.length l))
    in
    let total =
      List.sum (module Int) take_last ~f:(fun b -> b.Daily_price.volume)
    in
    Float.of_int total /. Float.of_int (List.length take_last)

let _classify_confirmation ~strong_threshold ~adequate_threshold ratio :
    volume_confirmation =
  if Float.(ratio >= strong_threshold) then Strong ratio
  else if Float.(ratio >= adequate_threshold) then Adequate ratio
  else Weak ratio

let analyze_breakout ~config ~bars ~event_idx : result option =
  let { lookback_weeks; strong_threshold; adequate_threshold; _ } = config in
  let n = List.length bars in
  if event_idx < 0 || event_idx >= n then None
  else if event_idx < lookback_weeks then None
  else
    let prior_bars =
      List.sub bars ~pos:(event_idx - lookback_weeks) ~len:lookback_weeks
    in
    let avg_vol =
      let total =
        List.sum (module Int) prior_bars ~f:(fun b -> b.Daily_price.volume)
      in
      Float.of_int total /. Float.of_int lookback_weeks
    in
    if Float.(avg_vol = 0.0) then None
    else
      let event_bar = List.nth_exn bars event_idx in
      let ev = event_bar.Daily_price.volume in
      let ratio = Float.of_int ev /. avg_vol in
      let confirmation =
        _classify_confirmation ~strong_threshold ~adequate_threshold ratio
      in
      Some
        {
          confirmation;
          event_volume = ev;
          avg_volume = avg_vol;
          volume_ratio = ratio;
        }

let is_pullback_confirmed ~config ~breakout_volume ~pullback_volume : bool =
  if breakout_volume <= 0 then false
  else
    let ratio = Float.of_int pullback_volume /. Float.of_int breakout_volume in
    Float.(ratio <= config.pullback_contraction)
