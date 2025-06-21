open Core
open Async
open Registry

(* Extract the symbol from the path, which is the last component of the path *)
let extract_symbol_from_path path =
  match String.split ~on:'/' path |> List.rev with
  | _filename :: symbol :: _ -> symbol
  | _ -> failwith "Path does not contain enough components to extract symbol"

(* Save the metadata to a file next to the CSV file *)
let metadata_path_for_csv csv_path =
  Fpath.v (String.chop_suffix_exn csv_path ~suffix:".csv" ^ ".metadata.sexp")

let save t ~csv_path =
  File_sexp.Sexp.save
    (module Metadata.T_sexp)
    t
    ~path:(metadata_path_for_csv csv_path)

let process_file csv_path : (string, string * string) Result.t Deferred.t =
  let symbol = extract_symbol_from_path csv_path in
  let lines = In_channel.read_lines csv_path in
  match Csv.Parser.parse_lines lines with
  | Error status -> Deferred.return (Error (symbol, status.message))
  | Ok prices -> (
      let metadata = Metadata.generate_metadata ~price_data:prices ~symbol () in
      match save metadata ~csv_path with
      | Ok () -> Deferred.return (Ok symbol)
      | Error status -> Deferred.return (Error (symbol, status.message)))

let print_result = function
  | Ok symbol -> printf "Successfully generated metadata for %s\n" symbol
  | Error (symbol, msg) ->
      printf "Failed to generate metadata for %s: %s\n" symbol msg

let print_results results =
  printf "\nProcessing %d files:\n" (List.length results);
  List.iter results ~f:print_result

let main ~csv_path ~dir () =
  match (csv_path, dir) with
  | Some csv_path, None ->
      let%bind result = process_file csv_path in
      print_result result;
      return ()
  | None, Some dir ->
      printf "Processing directory: %s\n" dir;
      let registry = create ~csv_dir:dir in
      let entries = list registry in
      printf "Found %d CSV files to process\n" (List.length entries);
      let%bind results =
        Deferred.List.map ~how:`Parallel entries ~f:(fun { csv_path; _ } ->
            process_file (Fpath.to_string csv_path))
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
