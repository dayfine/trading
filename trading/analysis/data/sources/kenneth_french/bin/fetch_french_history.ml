(** CLI: fetch + unzip + parse + persist a Kenneth French Data Library daily
    portfolio series.

    Usage:
    {v
      dune exec analysis/data/sources/kenneth_french/bin/fetch_french_history.exe -- \
        -dataset 5-industry-daily \
        -out dev/data/kenneth_french/5_industry_daily-YYYYMMDD.csv

      dune exec analysis/data/sources/kenneth_french/bin/fetch_french_history.exe -- \
        -dataset 49-industry-daily \
        -out dev/data/kenneth_french/49_industry_daily-YYYYMMDD.csv
    v}

    Behaviour:
    - HTTP-GETs the canonical ZIP URI
      ({!Kenneth_french.Kenneth_french_client.source_uri_5industry} or
      {!Kenneth_french.Kenneth_french_client.source_uri_49industry}) via system
      [curl] ({!French_curl_fetch.fetch}) and writes it to a tempfile.
    - Shell-outs to [unzip] to extract the inner CSV beside the tempfile.
    - Parses the inner CSV body through
      {!Kenneth_french.Kenneth_french_client.parse} (so any upstream schema
      drift fails loudly here, before the data is persisted).
    - Writes the parsed VW + EW blocks to the operator-supplied output path as a
      single canonical CSV: header line of [block,date,<industry names...>], one
      row per observation × per block, sentinel-derived [None] options emitted
      as empty cells.

    The CLI flag accepts a slug verbatim and rejects unknown values so future
    French datasets (e.g. factor / size-sort series) can plug in without
    breaking the contract. *)

open! Core
open Async
module Client = Kenneth_french.Kenneth_french_client

(* Hard-pinned set of supported datasets. Each entry maps a CLI slug to
   the canonical source URI and the expected inner-CSV filename in the
   ZIP. Extending this table is the only change required to onboard a new
   N-industry French daily dataset (the parser is column-count-driven). *)
let _datasets =
  [
    ( "5-industry-daily",
      Client.source_uri_5industry,
      "5_Industry_Portfolios_Daily.csv" );
    ( "49-industry-daily",
      Client.source_uri_49industry,
      "49_Industry_Portfolios_Daily.csv" );
  ]

let _dataset_slugs = List.map _datasets ~f:(fun (slug, _, _) -> slug)

let _lookup_dataset slug : (Uri.t * string, string) Result.t =
  match List.find _datasets ~f:(fun (s, _, _) -> String.equal s slug) with
  | Some (_, uri, inner) -> Ok (uri, inner)
  | None ->
      Error
        (Printf.sprintf "unknown dataset %S (supported: %s)" slug
           (String.concat ~sep:"," _dataset_slugs))

let _option_float_to_csv = function None -> "" | Some f -> Float.to_string f

let _row_to_csv ~block (obs : Client.daily_return) : string =
  let values =
    List.map obs.industry_returns ~f:(fun (_, v) -> _option_float_to_csv v)
  in
  String.concat ~sep:"," (block :: Date.to_string obs.date :: values)

let _series_header ~industries =
  String.concat ~sep:"," ("block" :: "date" :: industries)

let _series_to_lines ~block (series : Client.series) =
  List.map series.observations ~f:(fun obs -> _row_to_csv ~block obs)

let _write_parsed ~out_path (parsed : Client.parsed) : unit =
  let industries = parsed.value_weighted.industries in
  let header = _series_header ~industries in
  let vw_lines = _series_to_lines ~block:"VW" parsed.value_weighted in
  let ew_lines = _series_to_lines ~block:"EW" parsed.equal_weighted in
  Out_channel.write_lines out_path ((header :: vw_lines) @ ew_lines)

(* The Or_error error path is operator-facing: clean exit-1 with the
   underlying message on stderr, not a stack trace. The [_ : 'a] ascription
   defangs the compiler's "this statement never returns" warning at call
   sites that follow [_exit_with_error] with more code (e.g. inside an
   async match arm where every arm must produce a unit Deferred).

   We write directly to stdlib's [stderr] channel and flush before
   [Stdlib.exit]: [Core.eprintf] inside a [Command.async] body has been
   observed to drop output on synchronous exit (the Async scheduler may
   not flush OCaml's buffered channels on its own [exit_now] path). *)
let _exit_with_error : type a. string -> a =
 fun msg ->
  Stdlib.Printf.fprintf Stdlib.stderr "fetch_french_history: %s\n" msg;
  Stdlib.flush Stdlib.stderr;
  Stdlib.exit 1

let _print_summary ~out_path (parsed : Client.parsed) : unit =
  let n_vw = List.length parsed.value_weighted.observations in
  let n_ew = List.length parsed.equal_weighted.observations in
  let first_last (s : Client.series) =
    match (List.hd s.observations, List.last s.observations) with
    | Some a, Some b -> (Date.to_string a.date, Date.to_string b.date)
    | _ -> ("(empty)", "(empty)")
  in
  let vw_first, vw_last = first_last parsed.value_weighted in
  printf
    "fetch_french_history: wrote VW=%d EW=%d observations to %s (VW first %s, \
     last %s)\n"
    n_vw n_ew out_path vw_first vw_last

(* Shell out to [unzip] to extract the inner CSV from the downloaded ZIP.
   We keep this in the CLI (not the lib) to avoid an opam-dep on a Zip
   library — per the task brief, simpler is better here. The [-o] flag
   silently overwrites; [-d] sets the extraction directory. *)
let _unzip ~zip_path ~dest_dir : unit Or_error.t =
  let cmd =
    Printf.sprintf "unzip -o -q %s -d %s" (Filename.quote zip_path)
      (Filename.quote dest_dir)
  in
  match Sys_unix.command cmd with
  | 0 -> Ok ()
  | code ->
      Or_error.errorf "unzip exited %d for %s -> %s" code zip_path dest_dir

let _read_inner_csv ~stage_dir ~inner_name : string Or_error.t =
  let path = Filename.concat stage_dir inner_name in
  if Sys_unix.file_exists_exn path then Ok (In_channel.read_all path)
  else
    Or_error.errorf "inner CSV %S not found after unzip in %s" inner_name
      stage_dir

let _cleanup_stage stage_dir =
  let cmd = Printf.sprintf "rm -rf %s" (Filename.quote stage_dir) in
  ignore (Sys_unix.command cmd : int)

(* Fetch → unzip → read; on failure surface the underlying message. *)
let _download_and_extract ~uri ~inner_name : string Or_error.t Deferred.t =
  let stage_dir =
    Filename_unix.temp_dir ~in_dir:Filename.temp_dir_name "french_stage" ""
  in
  let zip_path = Filename.concat stage_dir "download.zip" in
  French_curl_fetch.fetch uri ~dest_path:zip_path >>| function
  | Error _ as e ->
      _cleanup_stage stage_dir;
      e
  | Ok () ->
      let result =
        let open Or_error.Let_syntax in
        let%bind () = _unzip ~zip_path ~dest_dir:stage_dir in
        _read_inner_csv ~stage_dir ~inner_name
      in
      _cleanup_stage stage_dir;
      result

let _handle_body ~out_path body : unit =
  match Client.parse body with
  | Error status -> _exit_with_error ("parse failed: " ^ Status.show status)
  | Ok parsed ->
      _write_parsed ~out_path parsed;
      _print_summary ~out_path parsed

let _run ~dataset ~out_path : unit Deferred.t =
  match _lookup_dataset dataset with
  | Error msg -> _exit_with_error msg
  | Ok (uri, inner_name) -> (
      _download_and_extract ~uri ~inner_name >>| function
      | Error err ->
          _exit_with_error
            ("download/extract failed: " ^ Error.to_string_hum err)
      | Ok body -> _handle_body ~out_path body)

let command =
  Command.async
    ~summary:
      "Fetch a Kenneth French Data Library daily portfolio series \
       (Dartmouth/Tuck), unzip + parse, write a canonical CSV."
    (let%map_open.Command dataset =
       flag "-dataset" (required string)
         ~doc:
           "SLUG dataset identifier (\"5-industry-daily\" or \
            \"49-industry-daily\")"
     and out_path =
       flag "-out" (required string)
         ~doc:"PATH output CSV path (will be overwritten)"
     in
     fun () -> _run ~dataset ~out_path)

let () = Command_unix.run command
