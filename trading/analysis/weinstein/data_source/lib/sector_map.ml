open Core

type t = string String.Map.t

let empty : t = String.Map.empty
let find (m : t) sym = Map.find m sym
let size (m : t) = Map.length m

let to_alist (m : t) =
  Map.to_alist m |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)

let of_alist pairs : t =
  List.fold pairs ~init:String.Map.empty ~f:(fun acc (sym, sec) ->
      Map.set acc ~key:sym ~data:sec)

let sectors_csv_path data_dir = Fpath.(data_dir / "sectors.csv")

(* Parse a single CSV line as (symbol, sector). This is a minimal parser —
   the Python scraper only emits unquoted ASCII symbols and sector names,
   so we do not need RFC 4180 quoted-field handling. Returns [None] for
   blank lines so the caller can drop them without an error. *)
let _split_line line =
  let line = String.strip line in
  if String.is_empty line then None
  else
    match String.lsplit2 line ~on:',' with
    | None -> None
    | Some (sym, rest) ->
        let sym = String.strip sym in
        let sector = String.strip rest in
        if String.is_empty sym || String.is_empty sector then None
        else Some (sym, sector)

let _is_header (sym, _sector) = String.equal (String.lowercase sym) "symbol"

let _parse_lines lines =
  List.filter_map lines ~f:_split_line
  |> List.filter ~f:(fun pair -> not (_is_header pair))

(* A missing sectors.csv is not an error — it's the "no sector data"
   state, and callers degrade gracefully. Any other I/O or parse error
   is surfaced as an Internal status. *)
let load ~data_dir =
  let path = sectors_csv_path data_dir in
  let path_str = Fpath.to_string path in
  if not (Stdlib.Sys.file_exists path_str) then Ok empty
  else
    try
      let lines = In_channel.read_lines path_str in
      let pairs = _parse_lines lines in
      Ok (of_alist pairs)
    with exn ->
      Status.error_internal
        (Printf.sprintf "Failed to load %s: %s" path_str (Exn.to_string exn))

let load_exn ~data_dir =
  match load ~data_dir with
  | Ok m -> m
  | Error err -> failwith (Status.show err)
