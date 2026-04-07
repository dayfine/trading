open Core
open Bos

(** Walk [dir] recursively, calling [f] on each file path. *)
let rec _walk_dir dir ~f =
  match OS.Dir.contents dir with
  | Error (`Msg msg) ->
      Printf.eprintf "Warning: cannot read directory %s: %s\n"
        (Fpath.to_string dir) msg
  | Ok entries ->
      List.iter entries ~f:(fun entry ->
          match OS.Path.stat entry with
          | Error _ -> ()
          | Ok stat -> (
              match stat.Caml_unix.st_kind with
              | Caml_unix.S_DIR -> _walk_dir entry ~f
              | Caml_unix.S_REG -> f entry
              | _ -> ()))

(** Read a metadata sexp file and return a JSON object for it. *)
let _read_metadata_entry path =
  match File_sexp.Sexp.load (module Metadata.T_sexp) ~path with
  | Error _ -> None
  | Ok meta ->
      let symbol = meta.Metadata.symbol in
      let start_date = Date.to_string meta.data_start_date in
      let end_date = Date.to_string meta.data_end_date in
      Some
        (`Assoc
           [
             ("symbol", `String symbol);
             ("cadence", `String "daily");
             ("start", `String start_date);
             ("end", `String end_date);
           ])

(** Collect all inventory entries from [data_dir], sorted by symbol. *)
let _collect_entries data_dir =
  let entries = ref [] in
  _walk_dir data_dir ~f:(fun path ->
      let filename = Fpath.filename path in
      if String.equal filename "data.metadata.sexp" then
        match _read_metadata_entry path with
        | None -> ()
        | Some entry -> entries := entry :: !entries);
  List.sort !entries ~compare:(fun a b ->
      let symbol_of = function
        | `Assoc fields ->
            List.Assoc.find_exn ~equal:String.equal fields "symbol"
            |> Yojson.Basic.to_string
        | _ -> ""
      in
      String.compare (symbol_of a) (symbol_of b))

let _write_inventory data_dir entries =
  let today = Date.to_string (Date.today ~zone:Time_float.Zone.utc) in
  let json =
    `Assoc [ ("generated_at", `String today); ("symbols", `List entries) ]
  in
  let out_path = Fpath.(data_dir / "inventory.json") in
  let json_str = Yojson.Basic.pretty_to_string json in
  match OS.File.write out_path json_str with
  | Ok () ->
      Printf.printf "Wrote %d symbols to %s\n%!" (List.length entries)
        (Fpath.to_string out_path)
  | Error (`Msg msg) ->
      Printf.eprintf "Error writing inventory: %s\n%!" msg;
      exit 1

let command =
  Command.basic ~summary:"Build data/inventory.json from cached metadata files"
    (let%map_open.Command data_dir =
       flag "data-dir"
         (optional_with_default "/workspaces/trading-1/data" string)
         ~doc:
           "PATH Directory containing cached symbol data (default: \
            /workspaces/trading-1/data)"
     in
     fun () ->
       let dir = Fpath.v data_dir in
       Printf.printf "Scanning %s ...\n%!" data_dir;
       let entries = _collect_entries dir in
       Printf.printf "Found %d symbols\n%!" (List.length entries);
       _write_inventory dir entries)

let () = Command_unix.run command
