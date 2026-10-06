open Core
module BR = Universe.Composition_bar_reader
module DVB = Universe.Dollar_volume_basis
module CA = Corporate_actions

type params = {
  years : int list;
  trailing_window_days : int;
  min_window_bars : int;
  basis : DVB.config;
  liquidity_floor : float;
  liquidity_lookback_bars : int;
}

type year_score = { year : int; legacy : float option; truth : float option }
type liquidity_year = { cal_year : int; weeks : int; lost : int; gained : int }

type t = {
  symbol : string;
  has_splits_file : bool;
  vendor_splits : CA.split list;
  confirmed : CA.split list;
  applied : CA.split list;
  volume_jump_shares : float list;
  scores : year_score list;
  rejected : (BR.bar * float) list;
  liquidity : liquidity_year list;
}

let _list_date ~year = Date.create_exn ~y:year ~m:Month.May ~d:31

let governing_list_year d =
  let y = Date.year d in
  if Date.( > ) d (_list_date ~year:y) then y else y - 1

(* ------------------------------------------------------------------ *)
(* Entry-gate flips                                                    *)
(* ------------------------------------------------------------------ *)

let _prefix_sums values =
  let sums = Array.create ~len:(Array.length values + 1) 0.0 in
  Array.iteri values ~f:(fun i v -> sums.(i + 1) <- sums.(i) +. v);
  sums

let _trailing_mean sums ~lookback i =
  let lo = Int.max 0 (i + 1 - lookback) in
  (sums.(i + 1) -. sums.(lo)) /. Float.of_int (i + 1 - lo)

let _is_week_end bars i =
  i = Array.length bars - 1
  ||
  let cur = bars.(i).BR.date and next = bars.(i + 1).BR.date in
  Date.diff next cur >= 7
  || Day_of_week.iso_8601_weekday_number (Date.day_of_week next)
     <= Day_of_week.iso_8601_weekday_number (Date.day_of_week cur)

let _bump table ~cal_year ~lost ~gained =
  Hashtbl.update table cal_year ~f:(fun prev ->
      let p =
        Option.value prev ~default:{ cal_year; weeks = 0; lost = 0; gained = 0 }
      in
      {
        p with
        weeks = p.weeks + 1;
        lost = (p.lost + if lost then 1 else 0);
        gained = (p.gained + if gained then 1 else 0);
      })

let _dv_sums basis ~splits bars =
  Array.map bars ~f:(DVB.bar_dollar_volume basis ~splits) |> _prefix_sums

let liquidity_flips params ~splits ~is_member bars =
  let legacy = _dv_sums DVB.Close_times_volume ~splits bars in
  let truth = _dv_sums DVB.True_dollars ~splits bars in
  let lookback = params.liquidity_lookback_bars in
  let table = Hashtbl.create (module Int) in
  Array.iteri bars ~f:(fun i (b : BR.bar) ->
      if _is_week_end bars i && is_member (governing_list_year b.date) then
        let pass sums =
          Float.(_trailing_mean sums ~lookback i >= params.liquidity_floor)
        in
        let p_legacy = pass legacy and p_true = pass truth in
        _bump table ~cal_year:(Date.year b.date) ~lost:(p_legacy && not p_true)
          ~gained:((not p_legacy) && p_true));
  Hashtbl.data table
  |> List.sort ~compare:(fun a b -> Int.compare a.cal_year b.cal_year)

(* ------------------------------------------------------------------ *)
(* Per-symbol scan                                                     *)
(* ------------------------------------------------------------------ *)

let _find arr date which =
  Array.binary_search arr which date ~compare:(fun (b : BR.bar) d ->
      Date.compare b.date d)

(* The bars in [[date - days, date]], by binary search on the sorted array. *)
let _window arr ~date ~days =
  let start = Date.add_days date (-days) in
  match
    ( _find arr start `First_greater_than_or_equal_to,
      _find arr date `Last_less_than_or_equal_to )
  with
  | Some lo, Some hi when lo <= hi ->
      Array.sub arr ~pos:lo ~len:(hi - lo + 1) |> Array.to_list
  | _ -> []

(* Active at a list date as the builder's inventory filter reads it: data
   starts by the window start and runs through the date. *)
let _active params arr year =
  let n = Array.length arr in
  let date = _list_date ~year in
  n > 0
  && Date.( <= ) arr.(0).BR.date
       (Date.add_days date (-params.trailing_window_days))
  && Date.( >= ) arr.(n - 1).BR.date date

let _score_year params ~splits arr year =
  let date = _list_date ~year in
  let bars = _window arr ~date ~days:params.trailing_window_days in
  let score config =
    DVB.score_window config ~splits ~date
      ~trailing_window_days:params.trailing_window_days
      ~min_window_bars:params.min_window_bars bars
  in
  let legacy = score DVB.legacy_config and truth = score params.basis in
  ({ year; legacy = legacy.avg; truth = truth.avg }, truth.rejected)

let _dedup_rejected rejected =
  List.dedup_and_sort rejected ~compare:(fun ((a : BR.bar), _) (b, _) ->
      Date.compare a.date b.date)

(* Jump shares of the confirmed splits large enough for the volume check to
   act on. *)
let _jump_shares (config : DVB.config) bars confirmed =
  List.filter confirmed ~f:(fun (s : CA.split) ->
      Float.(abs (log s.factor) >= config.volume_raw_min_log_factor))
  |> List.filter_map ~f:(DVB.volume_jump_share config bars)

let _read_attempts = 3
let _retry_pause_sec = 0.2

let retry_read f =
  let rec go n =
    match f () with
    | Some v -> Some v
    | None when n > 1 ->
        ignore (Core_unix.nanosleep _retry_pause_sec : float);
        go (n - 1)
    | None -> None
  in
  go _read_attempts

let _vendor_splits ~bars_root symbol =
  match
    retry_read (fun () ->
        Result.ok (CA.read_splits ~data_dir:(Fpath.v bars_root) symbol))
  with
  | Some splits -> (true, splits)
  | None -> (false, [])

let _scan_bars params ~bars_root ~is_member symbol bars =
  let has_splits_file, vendor_splits = _vendor_splits ~bars_root symbol in
  let confirmed = DVB.close_confirmed_splits params.basis bars vendor_splits in
  let applied =
    List.filter confirmed ~f:(DVB.volume_restated params.basis bars)
  in
  let arr = Array.of_list bars in
  let per_year =
    List.filter params.years ~f:(_active params arr)
    |> List.map ~f:(_score_year params ~splits:applied arr)
  in
  let volume_jump_shares = _jump_shares params.basis bars confirmed in
  {
    symbol;
    has_splits_file;
    vendor_splits;
    confirmed;
    applied;
    volume_jump_shares;
    scores = List.map per_year ~f:fst;
    rejected = _dedup_rejected (List.concat_map per_year ~f:snd);
    liquidity = liquidity_flips params ~splits:applied ~is_member arr;
  }

let scan params ~bars_root ~is_member symbol =
  retry_read (fun () -> BR.read_bars ~bars_root symbol)
  |> Option.map ~f:(_scan_bars params ~bars_root ~is_member symbol)
