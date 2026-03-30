open Core
open Types
open Indicator_types

type config = { rs_ma_period : int }

let default_config = { rs_ma_period = 52 }

type raw_rs = { date : Date.t; rs_value : float; rs_normalized : float }

(* ------------------------------------------------------------------ *)
(* Internal helpers                                                     *)
(* ------------------------------------------------------------------ *)

(** Align stock and benchmark bars on date, returning
    [(date, stock_close, bench_close)] triples for dates present in both. *)
let _align_bars ~stock_bars ~benchmark_bars : (Date.t * float * float) list =
  let bench_map =
    List.fold benchmark_bars ~init:Date.Map.empty ~f:(fun m b ->
        Map.set m ~key:b.Daily_price.date ~data:b.Daily_price.adjusted_close)
  in
  List.filter_map stock_bars ~f:(fun bar ->
      match Map.find bench_map bar.Daily_price.date with
      | None -> None
      | Some bench_close ->
          Some
            (bar.Daily_price.date, bar.Daily_price.adjusted_close, bench_close))

(** Convert [(date, rs_value)] pairs and the corresponding [ma_values] into a
    [raw_rs list].

    [ma_values] has [n - rs_ma_period + 1] entries and corresponds to the
    trailing window ending at each date starting at index [rs_ma_period - 1] in
    the aligned series. [offset = length aligned - length ma_values] aligns the
    MA output back onto the date/value arrays. *)
let _build_history dates raw_values ma_values ~offset : raw_rs list =
  List.mapi ma_values ~f:(fun i rs_ma ->
      let date = List.nth_exn dates (offset + i) in
      let rs_value = List.nth_exn raw_values (offset + i) in
      let rs_normalized =
        if Float.(rs_ma = 0.0) then 1.0 else rs_value /. rs_ma
      in
      { date; rs_value; rs_normalized })

(* ------------------------------------------------------------------ *)
(* Main function                                                        *)
(* ------------------------------------------------------------------ *)

let analyze ~config ~stock_bars ~benchmark_bars : raw_rs list option =
  let { rs_ma_period } = config in
  let aligned = _align_bars ~stock_bars ~benchmark_bars in
  let n = List.length aligned in
  if n < rs_ma_period then None
  else
    (* Step 1: compute the raw RS ratio series (stock / benchmark). *)
    let dates = List.map aligned ~f:(fun (d, _, _) -> d) in
    let raw_values =
      List.map aligned ~f:(fun (_, sc, bc) ->
          if Float.(bc = 0.0) then 1.0 else sc /. bc)
    in
    (* Step 2: compute the Mansfield zero-line — an SMA of the raw RS values.
       [Sma.calculate_sma] expects [indicator_value list]; we construct those
       from the raw float series, then extract the [.value] field back out. *)
    let indicator_values =
      List.map2_exn dates raw_values ~f:(fun date value -> { date; value })
    in
    let ma_indicator_values = Sma.calculate_sma indicator_values rs_ma_period in
    let ma_values = List.map ma_indicator_values ~f:(fun iv -> iv.value) in
    (* Step 3: normalize each raw RS value against its MA (the zero line).
       The MA is shorter than [raw_values] by [rs_ma_period - 1] entries;
       [offset] realigns the two series so that each MA value is paired with
       the corresponding date and raw RS value. *)
    let offset = n - List.length ma_values in
    Some (_build_history dates raw_values ma_values ~offset)
