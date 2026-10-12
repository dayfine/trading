open Core

(* ------------------------------------------------------------------ *)
(* Shared CSV parser — both Unicorn and Synthetic use YYYYMMDD,count   *)
(* ------------------------------------------------------------------ *)

(** Parse a [YYYYMMDD] integer-as-string into a Date. Returns [None] on any
    parse error. *)
let _parse_yyyymmdd s =
  let s = String.strip s in
  if String.length s <> 8 then None
  else
    try
      let y = Int.of_string (String.sub s ~pos:0 ~len:4) in
      let m = Int.of_string (String.sub s ~pos:4 ~len:2) in
      let d = Int.of_string (String.sub s ~pos:6 ~len:2) in
      Some (Date.create_exn ~y ~m:(Month.of_int_exn m) ~d)
    with _ -> None

(** Parse one CSV line into [(date, count)]. Returns [None] for malformed or
    unparseable rows. *)
let _parse_breadth_row line =
  match String.split line ~on:',' with
  | [ date_s; count_s ] -> (
      match
        (_parse_yyyymmdd date_s, Int.of_string_opt (String.strip count_s))
      with
      | Some date, Some count -> Some (date, count)
      | _ -> None)
  | _ -> None

let _insert_parsed_row tbl line =
  match _parse_breadth_row line with
  | Some (date, count) -> Hashtbl.set tbl ~key:date ~data:count
  | None -> ()

let _read_breadth_lines tbl ic =
  In_channel.iter_lines ic ~f:(_insert_parsed_row tbl)

(** Read one A/D count CSV from disk into a (date -> count) hashtable. Missing
    or unreadable files return an empty table. *)
let _read_count_file path =
  let tbl = Hashtbl.create (module Date) in
  if not (Stdlib.Sys.file_exists path) then tbl
  else
    try
      In_channel.with_file path ~f:(_read_breadth_lines tbl);
      tbl
    with _ -> tbl

(** Join the two count tables on date, filtering out rows where both counts are
    zero (placeholder rows). Returns sorted by date ascending. *)
let _join_counts ~advn ~decln ~filter_zeros : Macro.ad_bar list =
  Hashtbl.fold advn ~init:[] ~f:(fun ~key:date ~data:advancing acc ->
      match Hashtbl.find decln date with
      | Some declining when filter_zeros && advancing = 0 && declining = 0 ->
          acc
      | Some declining -> { Macro.date; advancing; declining } :: acc
      | None -> acc)
  |> List.sort ~compare:(fun (a : Macro.ad_bar) b -> Date.compare a.date b.date)

(* ------------------------------------------------------------------ *)
(* Unicorn CSV parser                                                   *)
(* ------------------------------------------------------------------ *)

let _unicorn_load ~data_dir =
  let breadth_dir = Filename.concat data_dir "breadth" in
  let advn_path = Filename.concat breadth_dir "nyse_advn.csv" in
  let decln_path = Filename.concat breadth_dir "nyse_decln.csv" in
  let advn = _read_count_file advn_path in
  let decln = _read_count_file decln_path in
  if Hashtbl.is_empty advn || Hashtbl.is_empty decln then []
  else _join_counts ~advn ~decln ~filter_zeros:true

module Unicorn = struct
  let load = _unicorn_load
end

(* ------------------------------------------------------------------ *)
(* Synthetic CSV parser                                                 *)
(* ------------------------------------------------------------------ *)

let _synthetic_load ~data_dir =
  let breadth_dir = Filename.concat data_dir "breadth" in
  let advn_path = Filename.concat breadth_dir "synthetic_advn.csv" in
  let decln_path = Filename.concat breadth_dir "synthetic_decln.csv" in
  let advn = _read_count_file advn_path in
  let decln = _read_count_file decln_path in
  if Hashtbl.is_empty advn || Hashtbl.is_empty decln then []
  else _join_counts ~advn ~decln ~filter_zeros:false

module Synthetic = struct
  let load = _synthetic_load
end

(* ------------------------------------------------------------------ *)
(* Gap detection                                                        *)
(* ------------------------------------------------------------------ *)

(* Longest Unicorn hole (calendar days between consecutive bars) left alone
   by composition. The longest legitimate NYSE closure in the archive is the
   2001-09-10 -> 2001-09-17 stretch (7 days); anything wider is missing data. *)
let default_max_interior_gap_days = 7

(** Consecutive pairs of a sorted date list more than [max_gap_days] calendar
    days apart, in order. *)
let _date_gaps dates ~max_gap_days =
  let rec loop acc = function
    | a :: (b :: _ as rest) ->
        let acc = if Date.diff b a > max_gap_days then (a, b) :: acc else acc in
        loop acc rest
    | [] | [ _ ] -> List.rev acc
  in
  loop [] dates

let _bar_dates bars = List.map bars ~f:(fun (bar : Macro.ad_bar) -> bar.date)
let gaps bars ~max_gap_days = _date_gaps (_bar_dates bars) ~max_gap_days

let gaps_in_window bars ~start_date ~end_date ~max_gap_days =
  let inside =
    List.filter (_bar_dates bars) ~f:(fun d ->
        Date.between d ~low:start_date ~high:end_date)
  in
  _date_gaps ((start_date :: inside) @ [ end_date ]) ~max_gap_days

let _format_gap_warning (lo, hi) =
  sprintf
    "WARNING: AD breadth gap %s -> %s (%d calendar days) inside the run \
     window; A-D macro indicators are frozen there"
    (Date.to_string lo) (Date.to_string hi) (Date.diff hi lo)

let gap_warnings bars ~skip ~start_date ~end_date ~max_gap_days =
  if skip then []
  else
    gaps_in_window bars ~start_date ~end_date ~max_gap_days
    |> List.map ~f:_format_gap_warning

(* ------------------------------------------------------------------ *)
(* Composition: Unicorn preferred, Synthetic fills tail + interior gaps *)
(* ------------------------------------------------------------------ *)

(** [true] when [d] lies strictly inside one of the [(lo, hi)] holes. *)
let _in_any_hole holes d =
  List.exists holes ~f:(fun (lo, hi) -> Date.( > ) d lo && Date.( < ) d hi)

let _compare_bar_dates (a : Macro.ad_bar) (b : Macro.ad_bar) =
  Date.compare a.date b.date

(** Keep the Synthetic bars [s] that fall after [cutoff] (Unicorn's last date)
    or inside a Unicorn hole wider than [max_gap_days], and merge them into the
    sorted Unicorn series [u]. *)
let _fill_from_synthetic ~max_gap_days ~cutoff u s =
  let holes = gaps u ~max_gap_days in
  let fill =
    List.filter s ~f:(fun (bar : Macro.ad_bar) ->
        Date.( > ) bar.date cutoff || _in_any_hole holes bar.date)
  in
  List.merge u fill ~compare:_compare_bar_dates

(** Compose Unicorn and Synthetic: Unicorn wins for every date it covers;
    Synthetic fills everything after Unicorn's last date and every interior
    Unicorn gap wider than [max_gap_days]. *)
let _compose ~max_gap_days ~unicorn ~synthetic =
  match (synthetic, List.last unicorn) with
  | s, None -> s
  | [], Some _ -> unicorn
  | s, Some (last : Macro.ad_bar) ->
      _fill_from_synthetic ~max_gap_days ~cutoff:last.date unicorn s

let load_with ~max_interior_gap_days ~data_dir =
  let unicorn = Unicorn.load ~data_dir in
  let synthetic = Synthetic.load ~data_dir in
  _compose ~max_gap_days:max_interior_gap_days ~unicorn ~synthetic

let load ~data_dir =
  load_with ~max_interior_gap_days:default_max_interior_gap_days ~data_dir
