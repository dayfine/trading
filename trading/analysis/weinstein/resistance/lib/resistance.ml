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
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let days_per_year = 365.25

let _take_last n lst =
  let len = List.length lst in
  if len <= n then lst else List.drop lst (len - n)

let _age_years date as_of_date : float =
  Float.of_int (Date.diff as_of_date date) /. days_per_year

(** Bucket index for a bar in the congestion-band grid rooted at
    [breakout_price]. Index 0 covers the first band above [breakout_price],
    index 1 the next, etc. *)
let _bucket_idx ~breakout_price ~band_size bar =
  let mid = (bar.Daily_price.high_price +. bar.Daily_price.low_price) /. 2.0 in
  let offset = Float.((mid - breakout_price) /. band_size) in
  Int.of_float (Float.round_down offset)

(** Group above-breakout bars into a hash table keyed by bucket index. Bars
    whose midpoint falls below [breakout_price] (bucket < 0) are discarded. *)
let _group_by_bucket ~breakout_price ~band_size bars =
  let tbl = Hashtbl.create (module Int) in
  List.iter bars ~f:(fun b ->
      if Float.(b.Daily_price.high_price > breakout_price) then
        let bkt = _bucket_idx ~breakout_price ~band_size b in
        if bkt >= 0 then
          Hashtbl.update tbl bkt ~f:(fun existing ->
              match existing with None -> [ b ] | Some bs -> b :: bs));
  tbl

(** Convert a single bucket's bars into a [resistance_zone]. *)
let _zone_of_bucket ~breakout_price ~band_size ~as_of_date bkt bkt_bars =
  let price_low = breakout_price +. (Float.of_int bkt *. band_size) in
  let most_recent_date =
    List.map bkt_bars ~f:(fun b -> b.Daily_price.date)
    |> List.max_elt ~compare:Date.compare
    |> Option.value_exn
  in
  {
    price_low;
    price_high = price_low +. band_size;
    weeks_of_trading = List.length bkt_bars;
    age_years = _age_years most_recent_date as_of_date;
  }

(* ------------------------------------------------------------------ *)
(* Core analysis functions                                              *)
(* ------------------------------------------------------------------ *)

let _find_zones ~bars ~breakout_price ~band_pct ~as_of_date =
  let band_size = breakout_price *. band_pct in
  let grouped = _group_by_bucket ~breakout_price ~band_size bars in
  Hashtbl.fold grouped ~init:[] ~f:(fun ~key:bkt ~data:bkt_bars acc ->
      _zone_of_bucket ~breakout_price ~band_size ~as_of_date bkt bkt_bars :: acc)
  |> List.sort ~compare:(fun a b -> Float.compare a.price_low b.price_low)

let _is_virgin_territory ~virgin_bars breakout_price =
  not
    (List.exists virgin_bars ~f:(fun b ->
         Float.(b.Daily_price.high_price > breakout_price)))

let _grade_zones ~config zones =
  let max_bars =
    List.map zones ~f:(fun z -> z.weeks_of_trading)
    |> List.max_elt ~compare:Int.compare
    |> Option.value ~default:0
  in
  if max_bars >= config.heavy_resistance_bars then Heavy_resistance
  else if max_bars >= config.moderate_resistance_bars then Moderate_resistance
  else Clean

let _classify_quality ~config ~virgin_bars ~zones breakout_price =
  if _is_virgin_territory ~virgin_bars breakout_price then Virgin_territory
  else if List.is_empty zones then Clean
  else _grade_zones ~config zones

(* ------------------------------------------------------------------ *)
(* Public interface                                                     *)
(* ------------------------------------------------------------------ *)

let analyze ~config ~bars ~breakout_price ~as_of_date =
  let virgin_bars = _take_last config.virgin_lookback_bars bars in
  let chart_bars = _take_last config.chart_lookback_bars bars in
  let zones_above =
    _find_zones ~bars:chart_bars ~breakout_price
      ~band_pct:config.congestion_band_pct ~as_of_date
  in
  let quality =
    _classify_quality ~config ~virgin_bars ~zones:zones_above breakout_price
  in
  { quality; breakout_price; zones_above; nearest_zone = List.hd zones_above }
