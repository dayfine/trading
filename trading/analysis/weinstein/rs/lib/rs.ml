open Core
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Config and defaults                                                  *)
(* ------------------------------------------------------------------ *)

type config = {
  rs_ma_period : int;
  trend_lookback : int;
  flat_threshold : float;
}

let default_config =
  { rs_ma_period = 52; trend_lookback = 4; flat_threshold = 0.98 }

(* ------------------------------------------------------------------ *)
(* Result types                                                         *)
(* ------------------------------------------------------------------ *)

type raw_rs = Relative_strength.raw_rs
(** Re-export the raw RS type from the canonical indicator. *)

type result = {
  current_rs : float;
  current_normalized : float;
  trend : rs_trend;
  history : raw_rs list;
}

(* ------------------------------------------------------------------ *)
(* Trend classification                                                 *)
(* ------------------------------------------------------------------ *)

(** Classify the RS trend from the normalized history.

    We compare the current [rs_normalized] value against the value
    [trend_lookback] bars ago:
    - Whether the stock is above or below the zero line (1.0) determines the
      zone (positive vs negative).
    - A zone change between then and now is a crossover.
    - Within the positive zone, the stock is "flat" if its RS has not declined
      by more than [flat_threshold] (e.g., 0.98 means a < 2% drop is still
      considered flat). *)
let _classify_trend ~trend_lookback ~flat_threshold (history : raw_rs list) :
    rs_trend =
  let n = List.length history in
  if n < 2 then Positive_flat
  else
    let cur = (List.last_exn history).rs_normalized in
    let prev =
      (List.nth_exn history (max 0 (n - 1 - trend_lookback))).rs_normalized
    in
    match (Float.(cur > 1.0), Float.(prev > 1.0)) with
    | true, false -> Bullish_crossover
    | false, true -> Bearish_crossover
    | true, true ->
        if Float.(cur > prev) then Positive_rising
        else if Float.(cur >= prev *. flat_threshold) then Positive_flat
        else Positive_flat
    | false, false ->
        if Float.(cur > prev) then Negative_improving else Negative_declining

(* ------------------------------------------------------------------ *)
(* Main function                                                        *)
(* ------------------------------------------------------------------ *)

let analyze ~config ~stock_bars ~benchmark_bars : result option =
  let { rs_ma_period; trend_lookback; flat_threshold } = config in
  let rs_config = Relative_strength.{ rs_ma_period } in
  match
    Relative_strength.analyze ~config:rs_config ~stock_bars ~benchmark_bars
  with
  | None -> None
  | Some history ->
      let current = List.last_exn history in
      let trend = _classify_trend ~trend_lookback ~flat_threshold history in
      Some
        {
          current_rs = current.rs_value;
          current_normalized = current.rs_normalized;
          trend;
          history;
        }
