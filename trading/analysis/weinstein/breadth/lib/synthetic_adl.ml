(** Synthetic advance/decline line computation. *)

open Core

type daily_counts = { advances : int; declines : int; total : int }
[@@deriving show, eq]

(* ---------- advance/decline computation ---------- *)

(** Record a price change direction for a given date into the accumulator. *)
let _record_direction tbl date direction =
  let adv, dec, tot =
    Hashtbl.find_or_add tbl date ~default:(fun () -> (0, 0, 0))
  in
  match direction with
  | `Advance -> Hashtbl.set tbl ~key:date ~data:(adv + 1, dec, tot + 1)
  | `Decline -> Hashtbl.set tbl ~key:date ~data:(adv, dec + 1, tot + 1)
  | `Unchanged -> Hashtbl.set tbl ~key:date ~data:(adv, dec, tot + 1)

(** Classify a price change and record it. *)
let _accumulate_direction tbl date ~prev_close ~close =
  if Float.( > ) close prev_close then _record_direction tbl date `Advance
  else if Float.( < ) close prev_close then _record_direction tbl date `Decline
  else _record_direction tbl date `Unchanged

(** Process one price point. Returns the current close for chaining. *)
let _process_price_point tbl prev (date, close) =
  Option.iter prev ~f:(fun prev_close ->
      _accumulate_direction tbl date ~prev_close ~close);
  Some close

(** Accumulate price changes for a single symbol's price series. *)
let _accumulate_symbol_changes tbl prices =
  if List.length prices >= 2 then
    let (_ : float option) =
      List.fold prices ~init:None ~f:(_process_price_point tbl)
    in
    ()

let compute_daily_changes ~min_stocks all_prices =
  let tbl = Hashtbl.create (module Date) in
  List.iter all_prices ~f:(_accumulate_symbol_changes tbl);
  Hashtbl.fold tbl ~init:[] ~f:(fun ~key:date ~data:(adv, dec, tot) acc ->
      if tot >= min_stocks then
        (date, { advances = adv; declines = dec; total = tot }) :: acc
      else acc)
  |> List.sort ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)

(* ---------- statistics ---------- *)

let _mean xs =
  let n = List.length xs in
  if n = 0 then 0.0
  else List.fold xs ~init:0.0 ~f:(fun acc x -> acc +. x) /. Float.of_int n

(** Compute variance components for Pearson correlation. *)
let _pearson_components xs ys ~mx ~my =
  List.fold2_exn xs ys ~init:(0.0, 0.0, 0.0) ~f:(fun (cov, var_x, var_y) x y ->
      let dx = x -. mx in
      let dy = y -. my in
      (cov +. (dx *. dy), var_x +. (dx *. dx), var_y +. (dy *. dy)))

let _pearson_correlation_impl xs ys =
  let mx = _mean xs in
  let my = _mean ys in
  let cov, var_x, var_y = _pearson_components xs ys ~mx ~my in
  let denom = Float.sqrt (var_x *. var_y) in
  if Float.( = ) denom 0.0 then 0.0 else cov /. denom

let _pearson_correlation xs ys =
  if List.is_empty xs then 0.0 else _pearson_correlation_impl xs ys

let _mean_absolute_error xs ys =
  let n = List.length xs in
  if n = 0 then 0.0
  else
    List.fold2_exn xs ys ~init:0.0 ~f:(fun acc x y -> acc +. Float.abs (x -. y))
    /. Float.of_int n

(* ---------- validation ---------- *)

type validation_result = {
  overlap_count : int;
  correlation : float;
  mae : float;
}
[@@deriving show, eq]

let validate_against_golden ~synthetic ~golden =
  let overlap_dates =
    Map.fold synthetic ~init:[] ~f:(fun ~key:date ~data:_ acc ->
        if Map.mem golden date then date :: acc else acc)
    |> List.sort ~compare:Date.compare
  in
  if List.is_empty overlap_dates then
    { overlap_count = 0; correlation = 0.0; mae = 0.0 }
  else
    let syn_vals =
      List.map overlap_dates ~f:(fun d ->
          Float.of_int (Map.find_exn synthetic d))
    in
    let gold_vals =
      List.map overlap_dates ~f:(fun d -> Float.of_int (Map.find_exn golden d))
    in
    let corr = _pearson_correlation syn_vals gold_vals in
    let mae = _mean_absolute_error syn_vals gold_vals in
    { overlap_count = List.length overlap_dates; correlation = corr; mae }
