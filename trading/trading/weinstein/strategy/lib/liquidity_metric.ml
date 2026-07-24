open Core

type aggregation = Mean | Median | Trimmed_mean
[@@deriving sexp, equal, compare]

(* Default symmetric trim fraction for [Trimmed_mean]: 10% off each tail. Over
   the default 20-bar window that drops the 2 largest and 2 smallest days —
   enough to absorb a single block-cross print (issue #2060) without discarding
   the body of the distribution. *)
let default_trim_pct = 0.1

(** Dollar volume of a single bar: close price times share volume. *)
let _bar_dollar_volume (bar : Types.Daily_price.t) =
  bar.close_price *. Float.of_int bar.volume

(** [bars] is oldest-first; take the trailing [lookback_days] bars (or all of
    them when fewer are available — never pads). *)
let _trailing_window ~lookback_days bars =
  let n = List.length bars in
  if n <= lookback_days then bars else List.drop bars (n - lookback_days)

(** Arithmetic mean of a non-empty float list. The same left-fold sum the
    pre-#2060 implementation used, so [Mean] readings are bit-identical. *)
let _mean values =
  List.sum (module Float) values ~f:Fn.id /. Float.of_int (List.length values)

let _sorted_array values =
  let sorted = Array.of_list values in
  Array.sort sorted ~compare:Float.compare;
  sorted

(** Median of a non-empty ascending-sorted array: the middle element for an odd
    count, the mean of the two central elements for an even count. *)
let _median_of_sorted sorted =
  let n = Array.length sorted in
  let mid = n / 2 in
  if n % 2 = 1 then sorted.(mid) else (sorted.(mid - 1) +. sorted.(mid)) /. 2.0

(** Observations to drop from EACH tail: [floor (n *. trim_pct)], clamped to
    [[0, (n - 1) / 2]] so at least one observation always survives. Total on a
    non-finite or non-positive [trim_pct] (trims nothing) and on a [trim_pct] at
    or above one half (trims maximally). *)
let _trim_count ~trim_pct ~n =
  let max_trim = (n - 1) / 2 in
  if not (Float.is_finite trim_pct) then 0
  else if Float.( <= ) trim_pct 0.0 then 0
  else if Float.( >= ) trim_pct 0.5 then max_trim
  else Int.min max_trim (Float.iround_down_exn (Float.of_int n *. trim_pct))

(** Symmetric trimmed mean of a non-empty ascending-sorted array. *)
let _trimmed_mean ~trim_pct sorted =
  let n = Array.length sorted in
  let k = _trim_count ~trim_pct ~n in
  Array.sub sorted ~pos:k ~len:(n - (2 * k)) |> Array.to_list |> _mean

let _aggregate ~aggregation ~trim_pct values =
  match aggregation with
  | Mean -> _mean values
  | Median -> _median_of_sorted (_sorted_array values)
  | Trimmed_mean -> _trimmed_mean ~trim_pct (_sorted_array values)

let dollar_adv ?(aggregation = Mean) ?(trim_pct = default_trim_pct)
    ~lookback_days (bars : Types.Daily_price.t list) =
  if lookback_days <= 0 then None
  else
    match _trailing_window ~lookback_days bars with
    | [] -> None
    | window ->
        let dollar_volumes = List.map window ~f:_bar_dollar_volume in
        Some (_aggregate ~aggregation ~trim_pct dollar_volumes)
