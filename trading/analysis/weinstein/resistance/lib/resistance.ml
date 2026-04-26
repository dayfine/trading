open Core
open Types
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Config and defaults                                                  *)
(* ------------------------------------------------------------------ *)

type config = {
  chart_lookback_bars : int;
      (** How many bars of history to analyse for zone density. *)
  virgin_lookback_bars : int;
      (** If no bar in this tail had a high above the breakout price, classify
          as virgin territory. *)
  congestion_band_pct : float;
      (** Price band width (fraction of breakout price) for bucketing bars. *)
  heavy_resistance_bars : int;
      (** Min bars in a zone to classify as Heavy resistance. *)
  moderate_resistance_bars : int;
      (** Min bars in a zone to classify as Moderate resistance. *)
}

let default_config =
  {
    chart_lookback_bars = 130;
    (* ~2.5 years of weekly bars *)
    virgin_lookback_bars = 520;
    (* ~10 years of weekly bars *)
    congestion_band_pct = 0.05;
    heavy_resistance_bars = 8;
    moderate_resistance_bars = 3;
  }

(* ------------------------------------------------------------------ *)
(* Result types                                                         *)
(* ------------------------------------------------------------------ *)

type resistance_zone = {
  price_low : float;
  price_high : float;
  weeks_of_trading : int;
  age_years : float;
}

type result = {
  quality : overhead_quality;
  breakout_price : float;
  zones_above : resistance_zone list;
  nearest_zone : resistance_zone option;
}

(* ------------------------------------------------------------------ *)
(* Callback bundle and constructor from a bar list                      *)
(* ------------------------------------------------------------------ *)

type callbacks = {
  get_high : bar_offset:int -> float option;
  get_low : bar_offset:int -> float option;
  get_date : bar_offset:int -> Date.t option;
  n_bars : int;
}

(** Build a [bar_offset]-indexed closure over a chronologically-ordered
    [Daily_price.t array]. [bar_offset:0] returns the newest bar's value;
    offsets past available depth return [None]. *)
let _make_lookup (arr : Daily_price.t array) (f : Daily_price.t -> 'a) :
    bar_offset:int -> 'a option =
  let n = Array.length arr in
  fun ~bar_offset ->
    let idx = n - 1 - bar_offset in
    if idx < 0 || idx >= n then None else Some (f arr.(idx))

let callbacks_from_bars ~(bars : Daily_price.t list) : callbacks =
  let arr = Array.of_list bars in
  {
    get_high = _make_lookup arr (fun b -> b.Daily_price.high_price);
    get_low = _make_lookup arr (fun b -> b.Daily_price.low_price);
    get_date = _make_lookup arr (fun b -> b.Daily_price.date);
    n_bars = Array.length arr;
  }

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let days_per_year = 365.25

let _age_years date as_of_date : float =
  Float.of_int (Date.diff as_of_date date) /. days_per_year

(** Bucket index for a (high, low) pair in the congestion-band grid rooted at
    [breakout_price]. Index 0 covers the first band above [breakout_price],
    index 1 the next, etc. *)
let _bucket_idx ~breakout_price ~band_size ~high ~low =
  let mid = (high +. low) /. 2.0 in
  let offset = Float.((mid - breakout_price) /. band_size) in
  Int.of_float (Float.round_down offset)

type _bucket_agg = { count : int; most_recent : Date.t }
(** Aggregate state per bucket while walking offsets: count of bars in the
    bucket and the most recent date among them. *)

(** Merge a fresh [date] into an existing bucket aggregate, keeping the larger
    of the prior [most_recent] and the new [date]. *)
let _merge_into_agg ~date (agg : _bucket_agg) : _bucket_agg =
  let most_recent =
    if Date.compare date agg.most_recent > 0 then date else agg.most_recent
  in
  { count = agg.count + 1; most_recent }

(** Update [tbl] with a single bar at [bar_offset], counting towards bucket
    [bkt] when [high > breakout_price] and [bkt >= 0]. The closures
    [get_high]/[get_low]/[get_date] are read once per offset. *)
let _accumulate_bucket tbl ~bkt ~date =
  Hashtbl.update tbl bkt ~f:(function
    | None -> { count = 1; most_recent = date }
    | Some agg -> _merge_into_agg ~date agg)

(** Try to read (high, low, date) at [bar_offset]. All three must be defined;
    any missing field skips the offset (treated as "no bar"). *)
let _read_offset (cb : callbacks) ~bar_offset : (float * float * Date.t) option
    =
  match
    (cb.get_high ~bar_offset, cb.get_low ~bar_offset, cb.get_date ~bar_offset)
  with
  | Some h, Some l, Some d -> Some (h, l, d)
  | _ -> None

(** Walk offsets [0 .. limit - 1] and accumulate above-breakout bars into the
    bucket table. Skips offsets where any of [get_high]/[get_low]/[get_date] is
    undefined; matches the bar-list path's "missing bar = no contribution"
    semantics. *)
let _accumulate_chart tbl ~callbacks ~breakout_price ~band_size ~limit =
  for off = 0 to limit - 1 do
    match _read_offset callbacks ~bar_offset:off with
    | None -> ()
    | Some (h, l, d) ->
        if Float.(h > breakout_price) then
          let bkt = _bucket_idx ~breakout_price ~band_size ~high:h ~low:l in
          if bkt >= 0 then _accumulate_bucket tbl ~bkt ~date:d
  done

(** Convert one bucket entry [(bkt, agg)] into a {!resistance_zone}. *)
let _zone_of_agg ~breakout_price ~band_size ~as_of_date ~bkt ~agg =
  let price_low = breakout_price +. (Float.of_int bkt *. band_size) in
  {
    price_low;
    price_high = price_low +. band_size;
    weeks_of_trading = agg.count;
    age_years = _age_years agg.most_recent as_of_date;
  }

(* ------------------------------------------------------------------ *)
(* Core analysis functions                                              *)
(* ------------------------------------------------------------------ *)

let _find_zones ~callbacks ~breakout_price ~band_pct ~as_of_date ~limit =
  let band_size = breakout_price *. band_pct in
  let tbl = Hashtbl.create (module Int) in
  _accumulate_chart tbl ~callbacks ~breakout_price ~band_size ~limit;
  Hashtbl.fold tbl ~init:[] ~f:(fun ~key:bkt ~data:agg acc ->
      _zone_of_agg ~breakout_price ~band_size ~as_of_date ~bkt ~agg :: acc)
  |> List.sort ~compare:(fun a b -> Float.compare a.price_low b.price_low)

(** True when no bar at offsets [0..limit-1] has [high > breakout_price]. *)
let _is_virgin_territory ~callbacks ~breakout_price ~limit =
  let rec loop off =
    if off >= limit then true
    else
      match callbacks.get_high ~bar_offset:off with
      | None -> loop (off + 1)
      | Some h -> if Float.(h > breakout_price) then false else loop (off + 1)
  in
  loop 0

let _grade_zones ~config zones =
  let max_bars =
    List.map zones ~f:(fun z -> z.weeks_of_trading)
    |> List.max_elt ~compare:Int.compare
    |> Option.value ~default:0
  in
  if max_bars >= config.heavy_resistance_bars then Heavy_resistance
  else if max_bars >= config.moderate_resistance_bars then Moderate_resistance
  else Clean

let _classify_quality ~config ~callbacks ~zones ~virgin_limit breakout_price =
  if _is_virgin_territory ~callbacks ~breakout_price ~limit:virgin_limit then
    Virgin_territory
  else if List.is_empty zones then Clean
  else _grade_zones ~config zones

(* ------------------------------------------------------------------ *)
(* Public interface                                                     *)
(* ------------------------------------------------------------------ *)

let analyze_with_callbacks ~(config : config) ~(callbacks : callbacks)
    ~breakout_price ~as_of_date =
  let virgin_limit = min config.virgin_lookback_bars callbacks.n_bars in
  let chart_limit = min config.chart_lookback_bars callbacks.n_bars in
  let zones_above =
    _find_zones ~callbacks ~breakout_price ~band_pct:config.congestion_band_pct
      ~as_of_date ~limit:chart_limit
  in
  let quality =
    _classify_quality ~config ~callbacks ~zones:zones_above ~virgin_limit
      breakout_price
  in
  { quality; breakout_price; zones_above; nearest_zone = List.hd zones_above }

let analyze ~config ~bars ~breakout_price ~as_of_date =
  let callbacks = callbacks_from_bars ~bars in
  analyze_with_callbacks ~config ~callbacks ~breakout_price ~as_of_date
