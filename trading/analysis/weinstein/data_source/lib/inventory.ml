open Core

type entry = {
  symbol : string;
  data_start_date : Date.t;
  data_end_date : Date.t;
}
[@@deriving sexp]

type t = { generated_at : Date.t; symbols : entry list } [@@deriving sexp]

let path ~data_dir = Fpath.(data_dir / "inventory.sexp")

let _entry_of_metadata (meta : Metadata.t) =
  {
    symbol = meta.symbol;
    data_start_date = meta.data_start_date;
    data_end_date = meta.data_end_date;
  }

let _stat_kind path =
  match Bos.OS.Path.stat path with
  | Error _ -> None
  | Ok stat -> Some stat.Caml_unix.st_kind

let _dispatch_entry ~walk ~f entry =
  match _stat_kind entry with
  | Some Caml_unix.S_DIR -> walk entry ~f
  | Some Caml_unix.S_REG -> f entry
  | _ -> ()

let rec _walk_dir dir ~f =
  match Bos.OS.Dir.contents dir with
  | Error (`Msg msg) ->
      Printf.eprintf "Warning: cannot read directory %s: %s\n"
        (Fpath.to_string dir) msg
  | Ok entries -> List.iter entries ~f:(_dispatch_entry ~walk:_walk_dir ~f)

(* First and last date of a [data.csv] (first column of the first and last data
   rows; the header row is skipped). [None] when the file has no data rows or
   an unparseable date. *)
let _csv_date_range path =
  let date_of_line line =
    match String.lsplit2 line ~on:',' with
    | Some (d, _) -> Option.try_with (fun () -> Date.of_string d)
    | None -> None
  in
  match In_channel.read_lines (Fpath.to_string path) with
  | exception _ -> None
  | _ :: (_ :: _ as rows) -> (
      match
        (date_of_line (List.hd_exn rows), date_of_line (List.last_exn rows))
      with
      | Some first, Some last -> Some (first, last)
      | _ -> None)
  | _ -> None

(* Entry derived from a [data.csv] whose directory has no readable
   [data.metadata.sexp]. The symbol is the directory name. *)
let _entry_of_csv fpath =
  let symbol = Fpath.(basename (parent fpath)) in
  Option.map (_csv_date_range fpath) ~f:(fun (data_start_date, data_end_date) ->
      { symbol; data_start_date; data_end_date })

(* Collect one file found by the walk: a loaded [data.metadata.sexp] entry, or a
   [data.csv] path to fall back on. *)
let _collect ~from_metadata ~csv_paths fpath =
  match Fpath.filename fpath with
  | "data.metadata.sexp" ->
      File_sexp.Sexp.load (module Metadata.T_sexp) ~path:fpath
      |> Result.iter ~f:(fun meta ->
          from_metadata := _entry_of_metadata meta :: !from_metadata)
  | "data.csv" -> csv_paths := fpath :: !csv_paths
  | _ -> ()

(* Entries from [data.csv] files whose symbol has no metadata entry. *)
let _csv_only_entries ~from_metadata csv_paths =
  let known =
    Hash_set.of_list
      (module String)
      (List.map from_metadata ~f:(fun e -> e.symbol))
  in
  List.filter_map csv_paths ~f:_entry_of_csv
  |> List.filter ~f:(fun e -> not (Hash_set.mem known e.symbol))

let build ~data_dir =
  let from_metadata = ref [] and csv_paths = ref [] in
  _walk_dir data_dir ~f:(_collect ~from_metadata ~csv_paths);
  (* Symbols fetched without a metadata file (e.g. bulk gap fetches) still count. *)
  let from_csv = _csv_only_entries ~from_metadata:!from_metadata !csv_paths in
  let symbols =
    List.sort (!from_metadata @ from_csv) ~compare:(fun a b ->
        String.compare a.symbol b.symbol)
  in
  { generated_at = Date.today ~zone:Time_float.Zone.utc; symbols }

let _sexpable () =
  (* Build a Sexpable module from the already-derived functions so we can
     use File_sexp.Sexp without duplicating the type definition. *)
  (module struct
    type nonrec t = t

    let sexp_of_t = sexp_of_t
    let t_of_sexp = t_of_sexp
  end : Base.Sexpable.S
    with type t = t)

let save t ~data_dir =
  File_sexp.Sexp.save (_sexpable ()) t ~path:(path ~data_dir)

let load ~data_dir = File_sexp.Sexp.load (_sexpable ()) ~path:(path ~data_dir)
