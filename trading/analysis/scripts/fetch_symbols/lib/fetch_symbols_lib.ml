open Core
open Async

let _resolve_token = function
  | Some key -> Ok key
  | None -> Error "No API key provided. Use --api-key."

(** Save [bars] to CSV and write the accompanying metadata file. *)
let _save_bars_and_meta ~data_dir ~bars symbol =
  let open Result.Let_syntax in
  let%bind storage = Csv.Csv_storage.create ~data_dir symbol in
  let%bind () = Csv.Csv_storage.save storage ~override:true bars in
  let meta = Metadata.generate_metadata ~price_data:bars ~symbol () in
  let sym_dir = Csv.Csv_storage.symbol_data_dir ~data_dir symbol in
  let meta_path = Fpath.(sym_dir / "data.metadata.sexp") in
  File_sexp.Sexp.save (module Metadata.T_sexp) meta ~path:meta_path

(** Log the result of caching [bars] and return [Ok symbol]. *)
let _cache_bars ~data_dir ~bars symbol =
  (match _save_bars_and_meta ~data_dir ~bars symbol with
  | Ok () -> printf "  OK: %d bars cached\n%!" (List.length bars)
  | Error e ->
      printf "  WARN: bars fetched but metadata write failed: %s\n%!"
        (Status.show e));
  return (Ok symbol)

(** Fetch and cache a single symbol, writing CSV + metadata. Empty bar lists are
    treated as a soft error — we warn and skip so the whole run keeps going and
    [Metadata.generate_metadata] is never called with [[]]. *)
let fetch_one ?fetch ~token ~data_dir symbol =
  printf "Fetching %s ...\n%!" symbol;
  let params : Eodhd.Http_client.historical_price_params =
    { symbol; start_date = None; end_date = None; period = Types.Cadence.Daily }
  in
  Eodhd.Http_client.get_historical_price ?fetch ~token ~params () >>= function
  | Error e ->
      printf "  ERROR: %s\n%!" (Status.show e);
      return (Error symbol)
  | Ok [] ->
      printf "  WARN: no bars returned for %s, skipping\n%!" symbol;
      return (Error symbol)
  | Ok bars -> _cache_bars ~data_dir ~bars symbol

let _main ~symbols ~data_dir_str ~api_key_flag () =
  match _resolve_token api_key_flag with
  | Error msg ->
      eprintf "%s\n%!" msg;
      exit 1
  | Ok token ->
      let data_dir = Fpath.v data_dir_str in
      Deferred.List.map ~how:`Sequential symbols ~f:(fetch_one ~token ~data_dir)
      >>= fun results ->
      let ok_count = List.count results ~f:Result.is_ok in
      let err_count = List.count results ~f:Result.is_error in
      printf "\nDone: %d fetched, %d errors.\n%!" ok_count err_count;
      return ()

let _parse_symbols csv =
  String.split ~on:',' csv |> List.map ~f:String.strip
  |> List.filter ~f:(fun s -> not (String.is_empty s))

let _symbols_from_universe ~data_dir_str =
  let data_dir = Fpath.v data_dir_str in
  Universe.get_deferred (Fpath.to_string data_dir) >>| function
  | Error e ->
      eprintf "Error loading universe: %s\n%!" (Status.show e);
      []
  | Ok instruments ->
      List.map instruments ~f:(fun (i : Types.Instrument_info.t) -> i.symbol)

let _resolve_symbols ~symbols_flag ~data_dir_str =
  match symbols_flag with
  | Some s -> return (_parse_symbols s)
  | None ->
      printf "No --symbols flag; reading from universe.sexp ...\n%!";
      _symbols_from_universe ~data_dir_str

let run ~symbols_flag ~data_dir_str ~api_key_flag () =
  let%bind sym_list = _resolve_symbols ~symbols_flag ~data_dir_str in
  if List.is_empty sym_list then (
    eprintf "No symbols to fetch.\n%!";
    return ())
  else (
    printf "Fetching %d symbols ...\n%!" (List.length sym_list);
    _main ~symbols:sym_list ~data_dir_str ~api_key_flag ())
