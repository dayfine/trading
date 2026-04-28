open Core
open Types
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Config and result                                                    *)
(* ------------------------------------------------------------------ *)

(* Reuses Resistance's config so the same defaults govern both
   directions and the screener doesn't need to maintain a parallel
   tuning surface. *)
type config = Resistance.config

let default_config = Resistance.default_config

type result = { quality : overhead_quality; breakdown_price : float }

(* ------------------------------------------------------------------ *)
(* Algorithm — callback-shaped, bar_offset:0 = newest                   *)
(* ------------------------------------------------------------------ *)

(* Bucket index for a (high, low) pair in the congestion-band grid
   rooted at [breakdown_price] and extending DOWNWARD. Index 0 covers
   the first band immediately below [breakdown_price], index 1 the
   next band further below, etc. Bars whose midpoint sits at or above
   [breakdown_price] yield a negative bucket and are filtered out by
   [_accumulate_below]. Mirror of [Resistance._bucket_idx]. *)
let _bucket_idx_below ~breakdown_price ~band_size ~high ~low =
  let mid = (high +. low) /. 2.0 in
  (* (breakdown - mid) is positive when the bar is below breakdown. *)
  let offset = (breakdown_price -. mid) /. band_size in
  Int.of_float (Float.round_down offset)

(* Try to read (high, low) at [bar_offset]. Both must be defined; any
   missing field skips the offset (treated as "no bar"). *)
let _read_offset (cb : Resistance.callbacks) ~bar_offset :
    (float * float) option =
  match (cb.get_high ~bar_offset, cb.get_low ~bar_offset) with
  | Some h, Some l -> Some (h, l)
  | _ -> None

(* Increment the count for [bkt] in [tbl]. *)
let _bump_bucket tbl ~bkt =
  Hashtbl.update tbl bkt ~f:(function None -> 1 | Some n -> n + 1)

(* Process a single bar reading at [bar_offset] — accumulate it into
   [tbl] when it qualifies (low pierced breakdown_price and bucket
   index is non-negative). Skip otherwise. *)
let _accumulate_one tbl ~breakdown_price ~band_size ~h ~l =
  if Float.(l < breakdown_price) then
    let bkt = _bucket_idx_below ~breakdown_price ~band_size ~high:h ~low:l in
    if bkt >= 0 then _bump_bucket tbl ~bkt

(* Walk offsets [0..limit-1] and accumulate below-breakdown bars into
   the bucket count table. Mirrors [Resistance._accumulate_chart] with
   the comparison flipped. *)
let _accumulate_below tbl ~callbacks ~breakdown_price ~band_size ~limit =
  for off = 0 to limit - 1 do
    match _read_offset callbacks ~bar_offset:off with
    | None -> ()
    | Some (h, l) -> _accumulate_one tbl ~breakdown_price ~band_size ~h ~l
  done

(* True when no bar at offsets [0..limit-1] has low below
   [breakdown_price]. The stock has never traded down to this level in
   the virgin window. Mirror of [Resistance._is_virgin_territory]. *)
let _is_virgin_below ~callbacks ~breakdown_price ~limit =
  let rec loop off =
    if off >= limit then true
    else
      match callbacks.Resistance.get_low ~bar_offset:off with
      | None -> loop (off + 1)
      | Some l -> if Float.(l < breakdown_price) then false else loop (off + 1)
  in
  loop 0

let _grade_count ~(config : config) ~max_bars : overhead_quality =
  if max_bars >= config.heavy_resistance_bars then Heavy_resistance
  else if max_bars >= config.moderate_resistance_bars then Moderate_resistance
  else Clean

(* ------------------------------------------------------------------ *)
(* Public entries                                                       *)
(* ------------------------------------------------------------------ *)

(* Compute the chart-density quality given the analysis is past the
   virgin check. Walks the chart-lookback window into a bucket table
   and grades the densest bucket. *)
let _classify_chart_density ~(config : config) ~callbacks ~breakdown_price =
  let chart_limit =
    min config.chart_lookback_bars callbacks.Resistance.n_bars
  in
  let band_size = breakdown_price *. config.congestion_band_pct in
  let tbl = Hashtbl.create (module Int) in
  _accumulate_below tbl ~callbacks ~breakdown_price ~band_size
    ~limit:chart_limit;
  let max_bars =
    Hashtbl.fold tbl ~init:0 ~f:(fun ~key:_ ~data:n acc -> max acc n)
  in
  if max_bars = 0 then Clean else _grade_count ~config ~max_bars

(* Compute quality given a non-degenerate (positive breakdown,
   non-empty callbacks) input. Splits virgin-territory short-circuit
   from chart density classification to keep the entry point flat. *)
let _quality_for_valid_input ~(config : config) ~callbacks ~breakdown_price =
  let virgin_limit =
    min config.virgin_lookback_bars callbacks.Resistance.n_bars
  in
  if _is_virgin_below ~callbacks ~breakdown_price ~limit:virgin_limit then
    Virgin_territory
  else _classify_chart_density ~config ~callbacks ~breakdown_price

let analyze_with_callbacks ~(config : config)
    ~(callbacks : Resistance.callbacks) ~breakdown_price ~as_of_date : result =
  let _ = as_of_date in
  let quality =
    if Float.(breakdown_price <= 0.0) || callbacks.n_bars <= 0 then
      Virgin_territory
    else _quality_for_valid_input ~config ~callbacks ~breakdown_price
  in
  { quality; breakdown_price }

let analyze ~(config : config) ~(bars : Daily_price.t list) ~breakdown_price
    ~as_of_date : result =
  let callbacks = Resistance.callbacks_from_bars ~bars in
  analyze_with_callbacks ~config ~callbacks ~breakdown_price ~as_of_date
