open Core
open Types
open Weinstein_types

type config = {
  chart_years : float;
  virgin_years : float;
  congestion_band_pct : float;
  heavy_resistance_weeks : int;
  moderate_resistance_weeks : int;
}

let default_config =
  {
    chart_years = 2.5;
    virgin_years = 10.0;
    congestion_band_pct = 0.05;
    heavy_resistance_weeks = 8;
    moderate_resistance_weeks = 3;
  }

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

(** Age in fractional years between [date] and [as_of_date]. *)
let _age_years date as_of_date : float =
  let days = Date.diff as_of_date date in
  Float.of_int days /. 365.25

(** Group bars above [breakout_price] into resistance zones using
    [congestion_band_pct] buckets. Each bucket is a [band_size]-wide price
    range. *)
let _find_zones ~bars ~breakout_price ~band_pct ~as_of_date :
    resistance_zone list =
  let band_size = breakout_price *. band_pct in
  (* Filter bars that traded above breakout_price *)
  let above_bars =
    List.filter bars ~f:(fun b ->
        Float.(b.Daily_price.high_price > breakout_price))
  in
  if List.is_empty above_bars then []
  else
    (* Bucket by price zone starting from breakout_price *)
    let bucket bar =
      let mid =
        (bar.Daily_price.high_price +. bar.Daily_price.low_price) /. 2.0
      in
      let offset = Float.((mid - breakout_price) /. band_size) in
      Int.of_float (Float.round_down offset)
    in
    let grouped = Hashtbl.create (module Int) in
    List.iter above_bars ~f:(fun b ->
        let bkt = bucket b in
        if bkt >= 0 then
          Hashtbl.update grouped bkt ~f:(fun existing ->
              match existing with None -> [ b ] | Some bs -> b :: bs));
    Hashtbl.fold grouped ~init:[] ~f:(fun ~key:bkt ~data:bkd_bars acc ->
        let price_low = breakout_price +. (Float.of_int bkt *. band_size) in
        let price_high = price_low +. band_size in
        let weeks = List.length bkd_bars in
        let most_recent_date =
          List.map bkd_bars ~f:(fun b -> b.Daily_price.date)
          |> List.max_elt ~compare:Date.compare
          |> Option.value_exn
        in
        let age = _age_years most_recent_date as_of_date in
        { price_low; price_high; weeks_of_trading = weeks; age_years = age }
        :: acc)
    |> List.sort ~compare:(fun a b -> Float.compare a.price_low b.price_low)

(** Classify overhead quality based on zones found. *)
let _classify_quality ~config ~virgin_years ~zones ~bars ~breakout_price
    ~as_of_date : overhead_quality =
  (* Check for virgin territory: no trading above this price in virgin_years *)
  let has_old_or_no_history =
    let above_ever =
      List.exists bars ~f:(fun b ->
          Float.(b.Daily_price.high_price > breakout_price))
    in
    if not above_ever then true
    else
      let oldest_above =
        List.filter bars ~f:(fun b ->
            Float.(b.Daily_price.high_price > breakout_price))
        |> List.map ~f:(fun b -> b.Daily_price.date)
        |> List.min_elt ~compare:Date.compare
        |> Option.value_exn
      in
      Float.(_age_years oldest_above as_of_date > virgin_years)
  in
  if has_old_or_no_history then Virgin_territory
  else if List.is_empty zones then Clean
  else
    (* Find the heaviest nearby zone *)
    let max_weeks =
      List.map zones ~f:(fun z -> z.weeks_of_trading)
      |> List.max_elt ~compare:Int.compare
      |> Option.value ~default:0
    in
    if max_weeks >= config.heavy_resistance_weeks then Heavy_resistance
    else if max_weeks >= config.moderate_resistance_weeks then
      Moderate_resistance
    else Clean

let analyze ~config ~bars ~breakout_price ~as_of_date : result =
  let { chart_years; virgin_years; congestion_band_pct; _ } = config in
  (* Filter to the relevant history window *)
  let cutoff_date =
    Date.add_days as_of_date (-Int.of_float (chart_years *. 365.25))
  in
  let relevant_bars =
    List.filter bars ~f:(fun b -> Date.(b.Daily_price.date >= cutoff_date))
  in
  let zones_above =
    _find_zones ~bars:relevant_bars ~breakout_price
      ~band_pct:congestion_band_pct ~as_of_date
  in
  let quality =
    _classify_quality ~config ~virgin_years ~zones:zones_above
      ~bars:relevant_bars ~breakout_price ~as_of_date
  in
  let nearest_zone = List.hd zones_above in
  { quality; breakout_price; zones_above; nearest_zone }
