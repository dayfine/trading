open Core
open Registry

let list_n_entries t n =
  let entries = list t in
  let entries = List.take entries n in
  List.iter entries ~f:(fun { symbol; csv_path } ->
      printf "%s: %s\n" symbol (Fpath.to_string csv_path))

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
