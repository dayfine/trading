(** Phase B offline writer for the daily-snapshot streaming pipeline.

    Reads a universe sexp + per-symbol CSVs, runs {!Snapshot_pipeline.Pipeline}
    once per symbol, writes one snapshot file per symbol under the output
    directory, and produces [<output-dir>/manifest.sexp] indexing the result.

    Optional [--incremental]: skips symbols whose source CSV is older than the
    existing snapshot file's recorded [csv_mtime] in a previous manifest at the
    same output path.

    Optional [--benchmark-symbol SYM]: routes that symbol's CSV bars into the
    pipeline's [benchmark_bars] argument so {!Snapshot_schema.RS_line} and
    {!Snapshot_schema.Macro_composite} are populated. Without it those columns
    are NaN per {!Snapshot_pipeline.Pipeline.build_for_symbol}'s contract.

    See [dev/plans/daily-snapshot-streaming-2026-04-27.md] §Phasing Phase B. *)

open Core
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_verifier = Snapshot_pipeline.Snapshot_verifier
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

let _csv_mtime ~data_dir ~symbol =
  let dir = Csv.Csv_storage.symbol_data_dir ~data_dir symbol in
  let csv_path = Fpath.add_seg dir "data.csv" |> Fpath.to_string in
  if Stdlib.Sys.file_exists csv_path then
    Some (Core_unix.stat csv_path).st_mtime
  else None

let _load_bars ~data_dir ~symbol =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error err ->
      Error
        (Status.invalid_argument_error
           (Printf.sprintf "create %s: %s" symbol (Status.show err)))
  | Ok storage -> Csv.Csv_storage.get storage ()

let _file_path ~output_dir ~symbol =
  Filename.concat output_dir (symbol ^ ".snap")

let _existing_manifest ~output_dir =
  let path = Filename.concat output_dir "manifest.sexp" in
  match Snapshot_manifest.read ~path with Ok m -> Some m | Error _ -> None

let _should_skip ~existing ~symbol ~csv_mtime ~schema =
  match existing with
  | None -> false
  | Some (m : Snapshot_manifest.t) ->
      if not (String.equal m.schema_hash schema.Snapshot_schema.schema_hash)
      then false
      else
        Option.value_map (Snapshot_manifest.find m ~symbol) ~default:false
          ~f:(fun e ->
            Float.( <= ) csv_mtime e.csv_mtime && Stdlib.Sys.file_exists e.path)

let _build_one_symbol ~symbol ~bars ~schema ~benchmark_bars ~output_dir
    ~csv_mtime =
  match Pipeline.build_for_symbol ~symbol ~bars ~schema ?benchmark_bars () with
  | Error err -> Error err
  | Ok rows -> (
      let path = _file_path ~output_dir ~symbol in
      match Snapshot_format.write ~path rows with
      | Error err -> Error err
      | Ok () ->
          let bytes = In_channel.read_all path in
          Ok
            {
              Snapshot_manifest.symbol;
              path;
              byte_size = String.length bytes;
              payload_md5 = Stdlib.Digest.to_hex (Stdlib.Digest.string bytes);
              csv_mtime;
            })

let _maybe_reuse ~existing ~symbol =
  match existing with
  | None -> None
  | Some m -> Snapshot_manifest.find m ~symbol

let _process_symbol ~data_dir ~schema ~benchmark_bars ~output_dir ~existing
    symbol =
  match _csv_mtime ~data_dir ~symbol with
  | None ->
      Printf.eprintf "skip %s: no CSV\n%!" symbol;
      None
  | Some csv_mtime -> (
      if _should_skip ~existing ~symbol ~csv_mtime ~schema then
        _maybe_reuse ~existing ~symbol
      else
        match _load_bars ~data_dir ~symbol with
        | Error err ->
            Printf.eprintf "skip %s: load: %s\n%!" symbol (Status.show err);
            None
        | Ok bars -> (
            match
              _build_one_symbol ~symbol ~bars ~schema ~benchmark_bars
                ~output_dir ~csv_mtime
            with
            | Ok entry -> Some entry
            | Error err ->
                Printf.eprintf "skip %s: build: %s\n%!" symbol (Status.show err);
                None))

(* Minimal universe-file reader — only the [Pinned] shape is supported in
   Phase B, which is all this writer needs (Full_sector_map requires the
   sectors.csv side channel that the runner threads in, irrelevant to the
   snapshot writer). The sexp shape mirrors [scenario_lib/universe_file.mli]:
   [(Pinned ((symbol AAPL) (sector "Information Technology")) ...)]. *)
type _pinned_entry = { symbol : string; sector : string [@warning "-69"] }
[@@deriving sexp]

type _universe_kind = Pinned of _pinned_entry list | Full_sector_map
[@@deriving sexp]

let _load_universe ~universe_path =
  let sexp = Sexp.load_sexp universe_path in
  match _universe_kind_of_sexp sexp with
  | Pinned entries -> List.map entries ~f:(fun e -> e.symbol)
  | Full_sector_map ->
      failwith
        "build_snapshots: Full_sector_map universes are not supported in Phase \
         B; pass a Pinned universe sexp"

let _benchmark_bars_opt ~data_dir ~benchmark_symbol =
  match benchmark_symbol with
  | None -> None
  | Some sym -> (
      match _load_bars ~data_dir ~symbol:sym with
      | Ok bars -> Some bars
      | Error err ->
          Printf.eprintf "warning: benchmark %s load failed: %s\n%!" sym
            (Status.show err);
          None)

let _verify_or_warn ~manifest_path =
  match Snapshot_verifier.verify_directory ~manifest_path with
  | Error err ->
      Printf.eprintf "verify failed: %s\n%!" (Status.show err);
      exit 2
  | Ok r ->
      Printf.printf "verify: %d/%d files OK (failed=%d)\n%!" r.passed r.total
        r.failed;
      if r.failed > 0 then exit 3

let _ensure_dir path =
  if not (Stdlib.Sys.file_exists path) then Stdlib.Sys.mkdir path 0o755

let main ~universe_path ~csv_data_dir ~output_dir ~benchmark_symbol ~incremental
    () =
  _ensure_dir output_dir;
  let schema = Snapshot_schema.default in
  let symbols = _load_universe ~universe_path in
  let data_dir = Fpath.v csv_data_dir in
  let benchmark_bars = _benchmark_bars_opt ~data_dir ~benchmark_symbol in
  let existing = if incremental then _existing_manifest ~output_dir else None in
  let t0 = Time_ns.now () in
  let entries =
    List.filter_map symbols
      ~f:
        (_process_symbol ~data_dir ~schema ~benchmark_bars ~output_dir ~existing)
  in
  let elapsed = Time_ns.diff (Time_ns.now ()) t0 in
  let manifest = Snapshot_manifest.create ~schema ~entries in
  let manifest_path = Filename.concat output_dir "manifest.sexp" in
  (match Snapshot_manifest.write ~path:manifest_path manifest with
  | Ok () ->
      Printf.printf "wrote %d entries to %s in %.2fs\n%!" (List.length entries)
        manifest_path
        (Time_ns.Span.to_sec elapsed)
  | Error err ->
      Printf.eprintf "manifest write failed: %s\n%!" (Status.show err);
      exit 1);
  _verify_or_warn ~manifest_path

let command =
  Command.basic
    ~summary:"Build per-symbol snapshot files for the daily-snapshot warehouse"
    (let%map_open.Command universe_path =
       flag "universe-path" (required string)
         ~doc:"PATH Universe sexp (Pinned shape required in Phase B)"
     and csv_data_dir =
       flag "csv-data-dir" (required string)
         ~doc:"PATH Directory containing per-symbol CSV history"
     and output_dir =
       flag "output-dir" (required string)
         ~doc:"PATH Directory where snapshot files + manifest are written"
     and benchmark_symbol =
       flag "benchmark-symbol" (optional string)
         ~doc:
           "SYM Optional benchmark ticker for RS_line / Macro_composite \
            (default: NaN columns)"
     and incremental =
       flag "incremental" no_arg
         ~doc:
           "Skip symbols whose CSV mtime <= the existing manifest's csv_mtime"
     in
     fun () ->
       main ~universe_path ~csv_data_dir ~output_dir ~benchmark_symbol
         ~incremental ())

let () = Command_unix.run command
