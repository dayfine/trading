open Core

let _sectors_filename = "sectors.csv"

(** Parse one CSV line into [(symbol, sector)] or [None] for malformed rows. *)
let _parse_line line =
  match String.split line ~on:',' with
  | symbol :: sector :: _ when String.length symbol > 0 ->
      Some (String.strip symbol, String.strip sector)
  | _ -> None

(** Read all lines from [ic] after the header, parsing each into the table. *)
let _read_rows ic tbl =
  let rec loop () =
    match Stdlib.In_channel.input_line ic with
    | None -> ()
    | Some line ->
        (match _parse_line line with
        | Some (symbol, sector) -> Hashtbl.set tbl ~key:symbol ~data:sector
        | None -> ());
        loop ()
  in
  loop ()

(** Skip the header line, then read all data rows. *)
let _read_csv ic tbl =
  match Stdlib.In_channel.input_line ic with
  | None -> ()
  | Some _header -> _read_rows ic tbl

let load ~data_dir =
  let path = Fpath.(to_string (data_dir / _sectors_filename)) in
  let tbl = Hashtbl.create (module String) in
  (match Stdlib.In_channel.open_gen [ Open_rdonly ] 0 path with
  | ic ->
      _read_csv ic tbl;
      Stdlib.In_channel.close ic
  | exception Sys_error _ -> ());
  tbl
