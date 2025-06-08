open Core
open Async

let extract_symbol_from_path path =
  match String.split ~on:'/' path |> List.rev with
  | _filename :: symbol :: _ -> symbol
  | _ -> failwith "Path does not contain enough components to extract symbol"

let process_file csv_path =
  let symbol = extract_symbol_from_path csv_path in
  try
    let metadata = Metadata.generate_metadata ~csv_path ~symbol () in
    Metadata.save metadata ~csv_path;
    Deferred.return (Ok symbol)
  with exn -> Deferred.return (Error (symbol, Exn.to_string exn))

let print_result = function
  | Ok symbol -> printf "Successfully generated metadata for %s\n" symbol
  | Error (symbol, msg) -> printf "Failed to generate metadata for %s: %s\n" symbol msg

let print_results results =
  printf "\nProcessing %d files:\n" (List.length results);
  List.iter results ~f:print_result

let list_csv_files_in_dir dir =
  match Bos.OS.Dir.fold_contents ~elements:`Files
    (fun p acc ->
      let path = Fpath.to_string p in
      if String.is_suffix ~suffix:".csv" path then path :: acc else acc)
    [] (Fpath.v dir)
  with
  | Ok files -> files
  | Error (`Msg msg) -> failwith msg

let main ~csv_path ~dir () =
  match (csv_path, dir) with
  | Some csv_path, None ->
      let%bind result = process_file csv_path in
      print_result result;
      return ()
  | None, Some dir ->
      printf "Processing directory: %s\n" dir;
      let csv_files = list_csv_files_in_dir dir in
      printf "Found %d CSV files to process\n" (List.length csv_files);
      let%bind results =
        Deferred.List.map ~how:`Parallel csv_files ~f:process_file
      in
      printf "Finished processing all files\n";
      print_results results;
      return ()
  | _ -> failwith "Exactly one of --csv-path or --dir must be specified"

let command =
  Command.async
    ~summary:
      "Generate metadata for a single CSV file or all CSV files in a directory"
    (let%map_open.Command csv_path =
       flag "csv-path" (optional string)
         ~doc:"CSV_PATH Path to a single CSV file"
     and dir =
       flag "dir" (optional string) ~doc:"DIR Directory containing CSV files"
     in
     fun () -> main ~csv_path ~dir ())

let () = Command_unix.run command
