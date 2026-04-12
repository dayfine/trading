open Core

let _sectors_filename = "sectors.csv"

(** Parse one CSV line into [(symbol, sector)] or [None] for malformed rows. *)
let _parse_line line =
  match String.split line ~on:',' with
  | symbol :: sector :: _ when String.length symbol > 0 ->
      Some (String.strip symbol, String.strip sector)
  | _ -> None

let load ~data_dir =
  let path = Fpath.(to_string (data_dir / _sectors_filename)) in
  let tbl = Hashtbl.create (module String) in
  (match Stdlib.In_channel.open_gen [ Open_rdonly ] 0 path with
  | ic ->
      (match Stdlib.In_channel.input_line ic with
      | None -> ()
      | Some _header ->
          let rec loop () =
            match Stdlib.In_channel.input_line ic with
            | None -> ()
            | Some line ->
                (match _parse_line line with
                | Some (symbol, sector) -> Hashtbl.set tbl ~key:symbol ~data:sector
                | None -> ());
                loop ()
          in
          loop ());
      Stdlib.In_channel.close ic
  | exception Sys_error _ -> ());
  tbl
