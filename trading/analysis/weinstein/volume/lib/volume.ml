open Core
open Types
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Config and defaults                                                  *)
(* ------------------------------------------------------------------ *)

type config = {
  lookback_bars : int;
  strong_threshold : float;
  adequate_threshold : float;
  pullback_contraction : float;
}

let default_config =
  {
    lookback_bars = 4;
    strong_threshold = 2.0;
    adequate_threshold = 1.5;
    pullback_contraction = 0.25;
  }

(* ------------------------------------------------------------------ *)
(* Result type                                                          *)
(* ------------------------------------------------------------------ *)

type result = {
  confirmation : volume_confirmation;
  event_volume : int;
  avg_volume : float;
  volume_ratio : float;
}

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let average_volume ~bars ~n : float =
  if n <= 0 || List.is_empty bars then 0.0
  else
    let recent = List.drop bars (max 0 (List.length bars - n)) in
    let total =
      List.sum (module Int) recent ~f:(fun b -> b.Daily_price.volume)
    in
    Float.of_int total /. Float.of_int (List.length recent)

let _classify_confirmation ~strong_threshold ~adequate_threshold ratio :
    volume_confirmation =
  if Float.(ratio >= strong_threshold) then Strong ratio
  else if Float.(ratio >= adequate_threshold) then Adequate ratio
  else Weak ratio

(** Compute the breakout result given the event bar and its prior baseline bars.
    Returns [None] when average volume is zero (no useful baseline). *)
let _compute_result ~config ~event_bar ~prior_bars : result option =
  let avg_vol = average_volume ~bars:prior_bars ~n:(List.length prior_bars) in
  if Float.(avg_vol = 0.0) then None
  else
    let ev = event_bar.Daily_price.volume in
    let ratio = Float.of_int ev /. avg_vol in
    let confirmation =
      _classify_confirmation ~strong_threshold:config.strong_threshold
        ~adequate_threshold:config.adequate_threshold ratio
    in
    Some
      {
        confirmation;
        event_volume = ev;
        avg_volume = avg_vol;
        volume_ratio = ratio;
      }

(* ------------------------------------------------------------------ *)
(* Public interface                                                     *)
(* ------------------------------------------------------------------ *)

let analyze_breakout ~config ~bars ~event_idx : result option =
  let n = List.length bars in
  if event_idx < 0 || event_idx >= n then None
  else if event_idx < config.lookback_bars then None
  else
    let prior_bars =
      List.sub bars
        ~pos:(event_idx - config.lookback_bars)
        ~len:config.lookback_bars
    in
    _compute_result ~config ~event_bar:(List.nth_exn bars event_idx) ~prior_bars

let is_pullback_confirmed ~config ~breakout_volume ~pullback_volume : bool =
  if breakout_volume <= 0 then false
  else
    let ratio = Float.of_int pullback_volume /. Float.of_int breakout_volume in
    Float.(ratio <= config.pullback_contraction)
