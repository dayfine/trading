open Core
module BR = Composition_bar_reader
module CA = Corporate_actions

type t = Close_times_volume | True_dollars [@@deriving sexp, eq, show]

type config = {
  basis : t;
  max_bar_dollar_volume : float;
  split_confirm_log_tolerance : float;
  split_search_bars : int;
  volume_check_bars : int;
  volume_raw_min_log_factor : float;
  volume_raw_min_share : float;
}
[@@deriving sexp, eq, show]

(* About twice the largest real US single-stock day (NVDA, March 2024). *)
let default_max_bar_dollar_volume = 2e11
let default_split_confirm_log_tolerance = 0.2
let default_split_search_bars = 2
let default_volume_check_bars = 10
let default_volume_raw_min_log_factor = Float.log 3.0
let default_volume_raw_min_share = 0.5

let legacy_config =
  {
    basis = Close_times_volume;
    max_bar_dollar_volume = default_max_bar_dollar_volume;
    split_confirm_log_tolerance = default_split_confirm_log_tolerance;
    split_search_bars = default_split_search_bars;
    volume_check_bars = default_volume_check_bars;
    volume_raw_min_log_factor = default_volume_raw_min_log_factor;
    volume_raw_min_share = default_volume_raw_min_share;
  }

let true_dollars_config = { legacy_config with basis = True_dollars }

(* ------------------------------------------------------------------ *)
(* Close confirmation                                                  *)
(* ------------------------------------------------------------------ *)

let confirms_split ~log_tolerance ~prev_close ~close factor =
  if Float.(prev_close <= 0.0 || close <= 0.0 || factor <= 0.0) then false
  else
    let log_jump = Float.log (prev_close /. close) in
    let off_factor = Float.abs (log_jump -. Float.log factor) in
    Float.(off_factor <= log_tolerance && off_factor < abs log_jump)

let _confirms_at ~log_tolerance arr factor i =
  i >= 1
  && i < Array.length arr
  && confirms_split ~log_tolerance ~prev_close:arr.(i - 1).BR.close
       ~close:arr.(i).BR.close factor

(* Bar indices nearest first: [i0], [i0 - 1], [i0 + 1], [i0 - 2], ... *)
let _search_order ~i0 ~search_bars =
  i0
  :: List.concat_map
       (List.range 1 (search_bars + 1))
       ~f:(fun k -> [ i0 - k; i0 + k ])

let _first_on_or_after arr date =
  Array.binary_search arr `First_greater_than_or_equal_to date
    ~compare:(fun (b : BR.bar) d -> Date.compare b.date d)

(* The split re-dated to the bar whose close confirms it, if any. A split
   dated before the first bar has no bar before it to scale. *)
let _confirming_bar config arr (s : CA.split) ~i0 =
  let confirms =
    _confirms_at ~log_tolerance:config.split_confirm_log_tolerance arr s.factor
  in
  List.find
    (_search_order ~i0 ~search_bars:config.split_search_bars)
    ~f:confirms

let _confirm_one config arr (s : CA.split) =
  let redate i = { s with date = arr.(i).BR.date } in
  match _first_on_or_after arr s.date with
  | None -> None
  | Some i0 when i0 = 0 && Date.( > ) arr.(0).BR.date s.date -> None
  | Some i0 -> Option.map (_confirming_bar config arr s ~i0) ~f:redate

let _by_date splits =
  List.sort splits ~compare:(fun (a : CA.split) b -> Date.compare a.date b.date)

let close_confirmed_splits config bars splits =
  let arr = Array.of_list bars in
  List.filter_map splits ~f:(_confirm_one config arr) |> _by_date

(* ------------------------------------------------------------------ *)
(* Volume restatement                                                  *)
(* ------------------------------------------------------------------ *)

let _median values =
  let sorted = List.sort values ~compare:Float.compare |> Array.of_list in
  let n = Array.length sorted in
  if n = 0 then None
  else if n % 2 = 1 then Some sorted.(n / 2)
  else Some ((sorted.((n / 2) - 1) +. sorted.(n / 2)) /. 2.0)

(* Median positive volume over [len] bars from [pos]; [None] when fewer than
   half of them have a positive volume. *)
let _side_median arr ~pos ~len =
  let lo = Int.max 0 pos and hi = Int.min (Array.length arr) (pos + len) in
  let vols =
    List.range lo hi
    |> List.filter_map ~f:(fun i ->
        let v = arr.(i).BR.volume in
        if Float.(v > 0.0) then Some v else None)
  in
  if List.length vols * 2 < len then None else _median vols

let volume_jump_share config bars (split : CA.split) =
  let log_f = Float.log split.factor in
  let len = config.volume_check_bars in
  let arr = Array.of_list bars in
  let open Option.Let_syntax in
  let%bind i =
    Array.findi arr ~f:(fun _ b -> Date.equal b.BR.date split.date)
    |> Option.map ~f:fst
  in
  let%bind () = Option.some_if Float.(log_f <> 0.0) () in
  let%bind before = _side_median arr ~pos:(i - len) ~len in
  let%map after = _side_median arr ~pos:i ~len in
  Float.log (after /. before) /. log_f

let volume_restated config bars (split : CA.split) =
  if Float.(abs (log split.factor) < config.volume_raw_min_log_factor) then true
  else
    match volume_jump_share config bars split with
    | Some share -> Float.(share < config.volume_raw_min_share)
    | None -> true

let applied_splits config bars splits =
  close_confirmed_splits config bars splits
  |> List.filter ~f:(volume_restated config bars)

(* ------------------------------------------------------------------ *)
(* Scoring                                                             *)
(* ------------------------------------------------------------------ *)

let split_divisor ~splits date =
  List.fold splits ~init:1.0 ~f:(fun acc (s : CA.split) ->
      if Date.( > ) s.date date then acc *. s.factor else acc)

let bar_dollar_volume basis ~splits (b : BR.bar) =
  let stored = b.close *. b.volume in
  match basis with
  | Close_times_volume -> stored
  | True_dollars -> stored /. split_divisor ~splits b.date

type window_score = { avg : float option; rejected : (BR.bar * float) list }

let _implausible config dv =
  match config.basis with
  | Close_times_volume -> false
  | True_dollars ->
      (not (Float.is_finite dv))
      || Float.(dv < 0.0)
      || Float.(dv > config.max_bar_dollar_volume)

let _in_window ~date ~trailing_window_days (b : BR.bar) =
  let start_d = Date.add_days date (-trailing_window_days) in
  Date.( >= ) b.date start_d && Date.( <= ) b.date date

let score_window config ~splits ~date ~trailing_window_days ~min_window_bars
    bars =
  let scored =
    List.filter_map bars ~f:(fun b ->
        if _in_window ~date ~trailing_window_days b then
          Some (b, bar_dollar_volume config.basis ~splits b)
        else None)
  in
  let rejected, kept =
    List.partition_tf scored ~f:(fun (_, dv) -> _implausible config dv)
  in
  let n = List.length kept in
  let avg =
    if n < min_window_bars then None
    else
      let total = List.fold kept ~init:0.0 ~f:(fun acc (_, dv) -> acc +. dv) in
      Some (total /. Float.of_int n)
  in
  { avg; rejected }

let read_applied_splits config ~bars_root symbol bars =
  match config.basis with
  | Close_times_volume -> Some []
  | True_dollars -> (
      match CA.read_splits ~data_dir:(Fpath.v bars_root) symbol with
      | Error _ -> None
      | Ok splits -> Some (applied_splits config bars splits))
