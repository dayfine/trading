open Core
open Async
open Bos

(** Read the API token: prefer [--api-key] flag, fall back to [EODHD_API_KEY]
    env var. *)
let _resolve_token api_key_flag =
  match api_key_flag with
  | Some key -> Ok key
  | None -> (
      match Sys.getenv "EODHD_API_KEY" with
      | Some key -> Ok key
      | None ->
          Error
            "No API key provided. Pass --api-key or set EODHD_API_KEY env var.")

(** Build the metadata file path next to the CSV file. *)
let _metadata_path csv_path =
  Fpath.v (String.chop_suffix_exn (Fpath.to_string csv_path) ~suffix:".csv")
  |> fun p -> Fpath.add_ext "metadata.sexp" p

(** Fetch and cache a single symbol, updating its metadata file. *)
let _fetch_one ~token ~data_dir symbol =
  printf "Fetching %s ...\n%!" symbol;
  let params : Eodhd.Http_client.historical_price_params =
    { symbol; start_date = None; end_date = None; period = Types.Cadence.Daily }
  in
  Eodhd.Http_client.get_historical_price ~token ~params () >>= function
  | Error e ->
      printf "  ERROR: %s\n%!" (Status.show e);
      return (Error symbol)
  | Ok bars ->
      let storage_result = Csv.Csv_storage.create ~data_dir symbol in
      let save_result =
        match storage_result with
        | Error e -> Error e
        | Ok storage -> Csv.Csv_storage.save storage ~override:true bars
      in
      let meta_result =
        match save_result with
        | Error e -> Error e
        | Ok () ->
            let meta = Metadata.generate_metadata ~price_data:bars ~symbol () in
            let first = String.get symbol 0 in
            let last = String.get symbol (String.length symbol - 1) in
            let csv_path =
              Fpath.(
                data_dir / String.make 1 first / String.make 1 last / symbol
                / "data.csv")
            in
            let meta_path = _metadata_path csv_path in
            File_sexp.Sexp.save (module Metadata.T_sexp) meta ~path:meta_path
      in
      (match meta_result with
      | Ok () -> printf "  OK: %d bars cached\n%!" (List.length bars)
      | Error e ->
          printf "  WARN: bars fetched but metadata write failed: %s\n%!"
            (Status.show e));
      return (Ok symbol)

(** Re-run the inventory builder after fetching symbols. *)
let _rebuild_inventory data_dir =
  let exe_dir = Filename.dirname Sys.executable_name in
  let inventory_exe = Filename.concat exe_dir "build_inventory.exe" in
  let cmd = Cmd.(v inventory_exe % "-data-dir" % Fpath.to_string data_dir) in
  match OS.Cmd.run cmd with
  | Ok () -> printf "Inventory updated.\n%!"
  | Error (`Msg msg) -> printf "Warning: could not update inventory: %s\n%!" msg

let main ~symbols ~data_dir_str ~api_key_flag () =
  match _resolve_token api_key_flag with
  | Error msg ->
      eprintf "%s\n%!" msg;
      exit 1
  | Ok token ->
      let data_dir = Fpath.v data_dir_str in
      Deferred.List.map ~how:`Sequential symbols
        ~f:(_fetch_one ~token ~data_dir)
      >>= fun results ->
      let ok_count = List.count results ~f:Result.is_ok in
      let err_count = List.count results ~f:Result.is_error in
      printf "\nDone: %d fetched, %d errors.\n%!" ok_count err_count;
      if ok_count > 0 then _rebuild_inventory data_dir;
      return ()

let command =
  Command.async ~summary:"Fetch named symbols from EODHD and cache them locally"
    (let%map_open.Command symbols =
       flag "symbols" (required string)
         ~doc:"SYM1,SYM2,... Comma-separated list of symbols to fetch"
     and data_dir =
       flag "data-dir"
         (optional_with_default "/workspaces/trading-1/data" string)
         ~doc:
           "PATH Directory to write cached data (default: \
            /workspaces/trading-1/data)"
     and api_key =
       flag "api-key" (optional string)
         ~doc:"KEY EODHD API key (overrides EODHD_API_KEY env var)"
     in
     fun () ->
       let sym_list =
         String.split ~on:',' symbols
         |> List.map ~f:String.strip
         |> List.filter ~f:(fun s -> not (String.is_empty s))
       in
       main ~symbols:sym_list ~data_dir_str:data_dir ~api_key_flag:api_key ())

let () = Command_unix.run command
