open Core

let min_universe_count = 100
let _breadth_file = "synthetic_breadth_daily.csv"

(** Parse an ISO [YYYY-MM-DD] date. [None] on any parse error (the header row
    reaches here as ["date"] and is rejected this way, so no separate
    header-skip step is needed). *)
let _parse_iso_date s =
  try Some (Date.of_string (String.strip s)) with _ -> None

let _int_of s = Int.of_string_opt (String.strip s)

(** The four count columns we keep, as a tuple. [None] if any is not an int. *)
let _counts_of n_s above_s nh_s nl_s =
  match (_int_of n_s, _int_of above_s, _int_of nh_s, _int_of nl_s) with
  | Some n, Some above, Some nh, Some nl -> Some (n, above, nh, nl)
  | _ -> None

(** Assemble a bar, dropping below-threshold universes — see the [.mli] on why
    holiday rows must not reach the cache. *)
let _bar_of (date, (n, above, nh, nl)) : Macro_types.breadth_bar option =
  if n < min_universe_count then None
  else
    Some
      {
        Macro_types.date;
        universe_count = n;
        above_ma_count = above;
        new_highs = nh;
        new_lows = nl;
      }

(** Parse one CSV row. Expects the seven columns of the documented header;
    [advances] / [declines] are read past but discarded (see the [.mli] on why).
    [None] for a malformed row, a non-date first column, or a below-threshold
    universe count. *)
let _parse_row line =
  match String.split line ~on:',' with
  | [ date_s; n_s; above_s; nh_s; nl_s; _advances; _declines ] ->
      Option.both (_parse_iso_date date_s) (_counts_of n_s above_s nh_s nl_s)
      |> Option.bind ~f:_bar_of
  | _ -> None

let _insert_row tbl line =
  match _parse_row line with
  | Some (bar : Macro_types.breadth_bar) ->
      Hashtbl.set tbl ~key:bar.date ~data:bar
  | None -> ()

let _read_rows tbl ic = In_channel.iter_lines ic ~f:(_insert_row tbl)

(** Read [path] into [tbl], keyed by date so a repeated date keeps its last row.
    An unreadable file leaves the table empty, matching the missing-file
    contract. *)
let _read_file tbl path =
  if Stdlib.Sys.file_exists path then
    try In_channel.with_file path ~f:(_read_rows tbl) with _ -> ()

let load ~data_dir =
  let path =
    Filename.concat (Filename.concat data_dir "breadth") _breadth_file
  in
  let tbl = Hashtbl.create (module Date) in
  _read_file tbl path;
  Hashtbl.data tbl
  |> List.sort ~compare:(fun (a : Macro_types.breadth_bar) b ->
      Date.compare a.date b.date)
