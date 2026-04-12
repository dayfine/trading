open Core

(* ------------------------------------------------------------------ *)
(* Unicorn CSV parser — module-private helpers                          *)
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
let _parse_unicorn_row line =
  match String.split line ~on:',' with
  | [ date_s; count_s ] -> (
      match
        (_parse_yyyymmdd date_s, Int.of_string_opt (String.strip count_s))
      with
      | Some date, Some count -> Some (date, count)
      | _ -> None)
  | _ -> None

let _insert_parsed_row tbl line =
  match _parse_unicorn_row line with
  | Some (date, count) -> Hashtbl.set tbl ~key:date ~data:count
  | None -> ()

let _read_unicorn_lines tbl ic =
  In_channel.iter_lines ic ~f:(_insert_parsed_row tbl)

(** Read one A/D count CSV from disk into a (date -> count) hashtable. Missing
    or unreadable files return an empty table. *)
let _read_unicorn_count_file path =
  let tbl = Hashtbl.create (module Date) in
  if not (Stdlib.Sys.file_exists path) then tbl
  else
    try
      In_channel.with_file path ~f:(_read_unicorn_lines tbl);
      tbl
    with _ -> tbl

(** Join the two count tables on date. A row with both [advancing] and
    [declining] equal to zero is treated as a placeholder and dropped — the
    upstream source pads the tail of the file with such rows. *)
let _join_unicorn_counts ~advn ~decln : Macro.ad_bar list =
  Hashtbl.fold advn ~init:[] ~f:(fun ~key:date ~data:advancing acc ->
      match Hashtbl.find decln date with
      | Some declining when advancing = 0 && declining = 0 -> acc
      | Some declining -> { Macro.date; advancing; declining } :: acc
      | None -> acc)
  |> List.sort ~compare:(fun (a : Macro.ad_bar) b -> Date.compare a.date b.date)

let _unicorn_load ~data_dir =
  let breadth_dir = Filename.concat data_dir "breadth" in
  let advn_path = Filename.concat breadth_dir "nyse_advn.csv" in
  let decln_path = Filename.concat breadth_dir "nyse_decln.csv" in
  let advn = _read_unicorn_count_file advn_path in
  let decln = _read_unicorn_count_file decln_path in
  if Hashtbl.is_empty advn || Hashtbl.is_empty decln then []
  else _join_unicorn_counts ~advn ~decln

module Unicorn = struct
  let load = _unicorn_load
end

let load ~data_dir = Unicorn.load ~data_dir
