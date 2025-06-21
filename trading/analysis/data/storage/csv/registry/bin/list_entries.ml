open Core
open Registry

(* Save the metadata to a file next to the CSV file *)
let metadata_path_for_csv csv_path =
  let path_string = Fpath.to_string csv_path in
  Fpath.v (String.chop_suffix_exn path_string ~suffix:".csv" ^ ".metadata.sexp")

let open_metadata_file ~csv_path =
  File_sexp.Sexp.load (module Metadata.T_sexp)
    ~path:(metadata_path_for_csv csv_path)

let wanted metadata =
  let open Metadata in
  metadata.has_volume
  && not metadata.last_n_prices_avg_below_10
  && not metadata.last_n_prices_avg_above_500

let list_n_entries t n =
  let entries = list t in
  let entries = List.take entries n in
  let total = List.length entries in
  let total =
    List.fold entries ~init:0 ~f:(fun acc { symbol; csv_path } ->
      match open_metadata_file ~csv_path with
      | Ok metadata ->
          let wanted = wanted metadata in
          if wanted then
            acc + 1
          else
            acc
      | Error _ -> acc
    )
  in
  printf "Total wanted: %d\n" total

let show_entry t symbol =
  match get t ~symbol with
  | Some { symbol; csv_path } ->
      printf "%s: %s\n" symbol (Fpath.to_string csv_path)
  | None -> printf "Symbol %s not found\n" symbol

let () =
  let open Command.Let_syntax in
  Command.basic ~summary:"List CSV registry entries"
    [%map_open
      let csv_dir =
        flag "csv-dir" (required string)
          ~doc:"DIR Directory containing CSV files"
      and n =
        flag "n" (optional int)
          ~doc:"NUMBER Show first N entries (default: show all)"
      and symbol =
        flag "symbol" (optional string)
          ~doc:"SYMBOL Show entry for specific symbol"
      in
      fun () ->
        let t = create ~csv_dir in
        match symbol with
        | Some sym -> show_entry t sym
        | None -> (
            match n with
            | Some n -> list_n_entries t n
            | None -> list_n_entries t (List.length (list t)))]
  |> Command_unix.run
