open Core

type dividend = {
  ex_date : Date.t;
  unadjusted_amount : float option;
  adjusted_amount : float;
}
[@@deriving show, eq]

type split = { date : Date.t; factor : float } [@@deriving show, eq]

let _dividends_file = "dividends.csv"
let _splits_file = "splits.csv"
let _dividends_header = "ex_date,unadjusted_amount,adjusted_amount"
let _splits_header = "date,factor"

let _path ~data_dir symbol file =
  Fpath.(Csv.Csv_storage.symbol_data_dir ~data_dir symbol / file)

let dividends_path ~data_dir symbol = _path ~data_dir symbol _dividends_file
let splits_path ~data_dir symbol = _path ~data_dir symbol _splits_file

(** Write [header] then [rows] to [path] through a sibling temp file and a
    rename, creating the parent directory first. *)
let _write_lines ~path ~header rows =
  let target = Fpath.to_string path in
  let tmp = target ^ ".tmp" in
  try
    Core_unix.mkdir_p (Fpath.to_string (Fpath.parent path));
    Out_channel.write_lines tmp (header :: rows);
    Core_unix.rename ~src:tmp ~dst:target;
    Ok ()
  with exn ->
    Status.error_internal
      (Printf.sprintf "failed to write %s: %s" target (Exn.to_string exn))

let _dividend_row d =
  String.concat ~sep:","
    [
      Date.to_string d.ex_date;
      Option.value_map d.unadjusted_amount ~default:"" ~f:Float.to_string;
      Float.to_string d.adjusted_amount;
    ]

let _split_row s = Date.to_string s.date ^ "," ^ Float.to_string s.factor

let write_dividends ~data_dir symbol divs =
  List.sort divs ~compare:(fun a b -> Date.compare a.ex_date b.ex_date)
  |> List.map ~f:_dividend_row
  |> _write_lines
       ~path:(dividends_path ~data_dir symbol)
       ~header:_dividends_header

let write_splits ~data_dir symbol splits =
  List.sort splits ~compare:(fun a b -> Date.compare a.date b.date)
  |> List.map ~f:_split_row
  |> _write_lines ~path:(splits_path ~data_dir symbol) ~header:_splits_header

(* Cell parsers raise on malformed input; [_read_rows] turns that into an
   [Invalid_argument] naming the row. *)
let _date cell = Date.of_string (String.strip cell)
let _float cell = Float.of_string (String.strip cell)

let _optional_float cell =
  if String.is_empty (String.strip cell) then None else Some (_float cell)

let _dividend_of_cells = function
  | [ d; u; a ] ->
      {
        ex_date = _date d;
        unadjusted_amount = _optional_float u;
        adjusted_amount = _float a;
      }
  | _ -> failwith "expected 3 cells"

let _split_of_cells = function
  | [ d; f ] -> { date = _date d; factor = _float f }
  | _ -> failwith "expected 2 cells"

let _parse_line ~file ~of_cells line =
  try Ok (of_cells (String.split line ~on:','))
  with _ ->
    Status.error_invalid_argument
      (Printf.sprintf "%s: malformed row %S" file line)

(** Read [path], check its header, and parse each non-blank row. *)
let _read_rows ~path ~header ~of_cells =
  let file = Fpath.to_string path in
  if not (Stdlib.Sys.file_exists file) then
    Status.error_not_found (Printf.sprintf "%s: not fetched" file)
  else
    match In_channel.read_lines file with
    | first :: rows when String.equal (String.strip first) header ->
        List.filter rows ~f:(fun l -> not (String.is_empty (String.strip l)))
        |> List.map ~f:(_parse_line ~file ~of_cells)
        |> Result.all
    | _ ->
        Status.error_invalid_argument
          (Printf.sprintf "%s: expected header %S" file header)
    | exception exn ->
        Status.error_internal
          (Printf.sprintf "failed to read %s: %s" file (Exn.to_string exn))

let read_dividends ~data_dir symbol =
  _read_rows
    ~path:(dividends_path ~data_dir symbol)
    ~header:_dividends_header ~of_cells:_dividend_of_cells

let read_splits ~data_dir symbol =
  _read_rows
    ~path:(splits_path ~data_dir symbol)
    ~header:_splits_header ~of_cells:_split_of_cells

let has_both_files ~data_dir symbol =
  let exists p = Stdlib.Sys.file_exists (Fpath.to_string p) in
  exists (dividends_path ~data_dir symbol)
  && exists (splits_path ~data_dir symbol)
