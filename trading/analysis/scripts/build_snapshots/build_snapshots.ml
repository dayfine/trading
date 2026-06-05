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

    Optional [--start-date YYYY-MM-DD] / [--end-date YYYY-MM-DD]: window each
    symbol's loaded bars to the inclusive [start, end] range {e before} building
    (the benchmark bars get the same window so RS_line / Macro_composite stay
    consistent). Omitting both is unchanged behaviour (full history). This makes
    a snapshot-mode warehouse cache-friendly: a full-history warehouse forces
    {!Daily_panels} to decode whole per-symbol files and blows the 1 GB LRU
    cache → thrash → re-decode every symbol every cycle (~100x slower than CSV
    mode). Windowing mirrors {!Csv_snapshot_builder}'s contract — see
    {!Bar_window} for the rationale and the {b warmup caveat}: indicators are
    computed only over the bars passed in, so the caller must set [--start-date]
    to the backtest's {e warmup_start} (early enough to cover 50-day / 30-week
    lookback), exactly as [Csv_snapshot_builder.build] is invoked with
    [~warmup_start]. The durable fix is a Phase-F windowed/mmap decode in
    {!Daily_panels}; this flag is the cheap interim mitigation.

    Checkpointing (added per dev/plans/data-pipeline-automation-2026-05-03.md):

    - Per-symbol atomic manifest update via
      {!Snapshot_pipeline.Snapshot_manifest.update_for_symbol}: after each
      [.snap] file lands, the directory manifest is rewritten via tempfile +
      atomic rename. Crash mid-run leaves a well-formed manifest with N entries
      where N is the number of symbols completed; [--incremental] on restart
      resumes correctly.
    - Periodic [progress.sexp] emission: every [--progress-every N] symbols
      (default 50), an atomic [progress.sexp] is written to the output dir so a
      tail-able tool can gauge progress mid-run.

    See [dev/plans/daily-snapshot-streaming-2026-04-27.md] §Phasing Phase B and
    [dev/plans/data-pipeline-automation-2026-05-03.md] for the checkpointing
    contract. *)

open Core
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_verifier = Snapshot_pipeline.Snapshot_verifier
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(** Default progress.sexp emission cadence: write a progress checkpoint after
    every 50 symbols. Configurable via [--progress-every N]. *)
let _default_progress_every = 50

type progress = {
  symbols_total : int;
  symbols_done : int;
  last_completed : string;
  started_at : float;
  updated_at : float;
}
[@@deriving sexp]
(** On-disk progress checkpoint shape. Atomically rewritten every
    [progress_every] symbols. Tail-able via standard shell tooling (sexp print).
    The fields use the canonical sexp serialization (Float.t ↔ "1234567890.5");
    start/update times are unix seconds since epoch. *)

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

(* Window a symbol's loaded bars to the inclusive [start_date, end_date] range
   before the snapshot pipeline sees them. Mirrors [Csv_snapshot_builder]'s
   windowing so a snapshot-mode warehouse stays cache-friendly (see
   {!Bar_window} for the perf rationale + warmup caveat). When both bounds are
   [None] the bars pass through unchanged. *)
let _window_bars ~start_date ~end_date bars =
  Bar_window.filter ?start:start_date ?end_:end_date bars

(* Load a symbol's bars and apply the date window. The window is also threaded
   into the benchmark load (see [_load_benchmark_bars]) so RS_line /
   Macro_composite are computed over the same range. *)
let _load_windowed_bars ~data_dir ~start_date ~end_date ~symbol =
  match _load_bars ~data_dir ~symbol with
  | Error _ as err -> err
  | Ok bars -> Ok (_window_bars ~start_date ~end_date bars)

let _file_path ~output_dir ~symbol =
  Filename.concat output_dir (symbol ^ ".snap")

let _existing_manifest ~output_dir =
  let path = Filename.concat output_dir "manifest.sexp" in
  match Snapshot_manifest.read ~path with Ok m -> Some m | Error _ -> None

let _entry_is_current ~csv_mtime (e : Snapshot_manifest.file_metadata) =
  Float.( <= ) csv_mtime e.csv_mtime && Stdlib.Sys.file_exists e.path

let _should_skip ~existing ~symbol ~csv_mtime ~schema =
  match existing with
  | None -> false
  | Some (m : Snapshot_manifest.t) ->
      String.equal m.schema_hash schema.Snapshot_schema.schema_hash
      && Option.value_map
           (Snapshot_manifest.find m ~symbol)
           ~default:false
           ~f:(_entry_is_current ~csv_mtime)

let _file_metadata ~symbol ~path ~csv_mtime ~active_through =
  let bytes = In_channel.read_all path in
  {
    Snapshot_manifest.symbol;
    path;
    byte_size = String.length bytes;
    payload_md5 = Stdlib.Digest.to_hex (Stdlib.Digest.string bytes);
    csv_mtime;
    active_through;
  }

(** Last-bar [active_through] is the symbol's delisting marker. The CSV loader
    sets the same value on every row of a symbol's history (or [None] throughout
    for still-trading symbols), so reading the tail is equivalent to reading any
    row. Surfaces to the runtime via the manifest → [Daily_panels] →
    [Snapshot_callbacks] → reconstituted [Daily_price.t] rows path so the
    screener PI filter can see it. *)
let _active_through_of_bars (bars : Types.Daily_price.t list) : Date.t option =
  List.last bars
  |> Option.bind ~f:(fun (b : Types.Daily_price.t) -> b.active_through)

let _write_and_checksum ~symbol ~path ~csv_mtime ~active_through rows =
  match Snapshot_format.write ~path rows with
  | Error err -> Error err
  | Ok () -> Ok (_file_metadata ~symbol ~path ~csv_mtime ~active_through)

let _build_one_symbol ~symbol ~bars ~schema ~benchmark_bars ~output_dir
    ~csv_mtime =
  let path = _file_path ~output_dir ~symbol in
  let active_through = _active_through_of_bars bars in
  match Pipeline.build_for_symbol ~symbol ~bars ~schema ?benchmark_bars () with
  | Error err -> Error err
  | Ok rows -> _write_and_checksum ~symbol ~path ~csv_mtime ~active_through rows

let _maybe_reuse ~existing ~symbol =
  match existing with
  | None -> None
  | Some m -> Snapshot_manifest.find m ~symbol

let _checkpoint_manifest ~manifest_path ~schema entry =
  match
    Snapshot_manifest.update_for_symbol ~path:manifest_path ~schema entry
  with
  | Ok () -> ()
  | Error err ->
      Printf.eprintf "manifest checkpoint failed for %s: %s\n%!"
        entry.Snapshot_manifest.symbol (Status.show err)

let _build_or_log ~symbol ~bars ~schema ~benchmark_bars ~output_dir ~csv_mtime
    ~manifest_path ~checkpoint =
  match
    _build_one_symbol ~symbol ~bars ~schema ~benchmark_bars ~output_dir
      ~csv_mtime
  with
  | Error err ->
      Printf.eprintf "skip %s: build: %s\n%!" symbol (Status.show err);
      None
  | Ok entry ->
      if checkpoint then _checkpoint_manifest ~manifest_path ~schema entry;
      Some entry

(** Load bars for [symbol] and build its snapshot entry. Returns [None] on load
    or build failure (logs the error). On success, optionally checkpoints the
    manifest entry if [checkpoint] is set. *)
let _try_build_and_checkpoint ~data_dir ~start_date ~end_date ~schema
    ~benchmark_bars ~output_dir ~manifest_path ~checkpoint ~csv_mtime symbol =
  match _load_windowed_bars ~data_dir ~start_date ~end_date ~symbol with
  | Error err ->
      Printf.eprintf "skip %s: load: %s\n%!" symbol (Status.show err);
      None
  | Ok bars ->
      _build_or_log ~symbol ~bars ~schema ~benchmark_bars ~output_dir ~csv_mtime
        ~manifest_path ~checkpoint

let _process_symbol ~data_dir ~start_date ~end_date ~schema ~benchmark_bars
    ~output_dir ~existing ~manifest_path ~checkpoint symbol =
  match _csv_mtime ~data_dir ~symbol with
  | None ->
      Printf.eprintf "skip %s: no CSV\n%!" symbol;
      None
  | Some csv_mtime ->
      if _should_skip ~existing ~symbol ~csv_mtime ~schema then
        _maybe_reuse ~existing ~symbol
      else
        _try_build_and_checkpoint ~data_dir ~start_date ~end_date ~schema
          ~benchmark_bars ~output_dir ~manifest_path ~checkpoint ~csv_mtime
          symbol

(* Universe-file reader. Accepts either the [Pinned] shape
   ([scenario_lib/universe_file]) or an [analysis/data/universe] composition
   snapshot (the shape the goldens' universes use). See {!Universe_loader}.
   Exits non-zero on an unsupported shape (Full_sector_map, all-synthetic, or a
   malformed sexp) rather than building an empty warehouse silently. *)
let _load_universe ~universe_path =
  match Universe_loader.symbols_of_path ~path:universe_path with
  | Ok symbols -> symbols
  | Error err ->
      Printf.eprintf "build_snapshots: %s\n%!" (Status.show err);
      exit 1

let _load_benchmark_bars ~data_dir ~start_date ~end_date sym =
  match _load_windowed_bars ~data_dir ~start_date ~end_date ~symbol:sym with
  | Ok bars -> Some bars
  | Error err ->
      Printf.eprintf "warning: benchmark %s load failed: %s\n%!" sym
        (Status.show err);
      None

let _benchmark_bars_opt ~data_dir ~start_date ~end_date ~benchmark_symbol =
  Option.bind benchmark_symbol
    ~f:(_load_benchmark_bars ~data_dir ~start_date ~end_date)

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

(** Atomically write [progress.sexp] under [output_dir]. Tempfile + rename so a
    tailing reader never observes a torn write. *)
let _write_progress ~output_dir ~progress =
  let path = Filename.concat output_dir "progress.sexp" in
  let tmp = path ^ ".tmp" in
  try
    let data = Sexp.to_string_hum (sexp_of_progress progress) in
    Out_channel.write_all tmp ~data;
    Stdlib.Sys.rename tmp path
  with Sys_error msg | Failure msg -> (
    Printf.eprintf "progress write failed: %s\n%!" msg;
    try Stdlib.Sys.remove tmp with _ -> ())

let _make_progress ~symbols_total ~symbols_done ~last_completed ~started_at =
  {
    symbols_total;
    symbols_done;
    last_completed;
    started_at;
    updated_at = Core_unix.time ();
  }

let _maybe_emit_progress ~output_dir ~progress_every ~symbols_total
    ~symbols_done ~last_completed ~started_at =
  if symbols_done > 0 && symbols_done mod progress_every = 0 then
    _write_progress ~output_dir
      ~progress:
        (_make_progress ~symbols_total ~symbols_done ~last_completed ~started_at)

let _last_symbol entries =
  match List.last entries with
  | Some e -> e.Snapshot_manifest.symbol
  | None -> ""

let _emit_final_progress ~output_dir ~symbols_total ~entries ~started_at =
  let symbols_done = List.length entries in
  let last_completed = _last_symbol entries in
  _write_progress ~output_dir
    ~progress:
      (_make_progress ~symbols_total ~symbols_done ~last_completed ~started_at)

let _write_final_manifest ~manifest_path ~schema ~entries ~elapsed =
  let manifest = Snapshot_manifest.create ~schema ~entries in
  match Snapshot_manifest.write ~path:manifest_path manifest with
  | Ok () ->
      Printf.printf "wrote %d entries to %s in %.2fs\n%!" (List.length entries)
        manifest_path
        (Time_ns.Span.to_sec elapsed)
  | Error err ->
      Printf.eprintf "manifest write failed: %s\n%!" (Status.show err);
      exit 1

let _fold_symbol ~data_dir ~start_date ~end_date ~schema ~benchmark_bars
    ~output_dir ~existing ~manifest_path ~progress_every ~symbols_total
    ~started_at i acc symbol =
  match
    _process_symbol ~data_dir ~start_date ~end_date ~schema ~benchmark_bars
      ~output_dir ~existing ~manifest_path ~checkpoint:true symbol
  with
  | None -> acc
  | Some entry ->
      let symbols_done = i + 1 in
      _maybe_emit_progress ~output_dir ~progress_every ~symbols_total
        ~symbols_done ~last_completed:symbol ~started_at;
      acc @ [ entry ]

let main ~universe_path ~csv_data_dir ~output_dir ~benchmark_symbol ~start_date
    ~end_date ~incremental ~progress_every () =
  _ensure_dir output_dir;
  let schema = Snapshot_schema.default in
  let symbols = _load_universe ~universe_path in
  let symbols_total = List.length symbols in
  let data_dir = Fpath.v csv_data_dir in
  let benchmark_bars =
    _benchmark_bars_opt ~data_dir ~start_date ~end_date ~benchmark_symbol
  in
  let existing = if incremental then _existing_manifest ~output_dir else None in
  let manifest_path = Filename.concat output_dir "manifest.sexp" in
  let started_at = Core_unix.time () in
  let t0 = Time_ns.now () in
  let entries =
    List.foldi symbols ~init:[]
      ~f:
        (_fold_symbol ~data_dir ~start_date ~end_date ~schema ~benchmark_bars
           ~output_dir ~existing ~manifest_path ~progress_every ~symbols_total
           ~started_at)
  in
  let elapsed = Time_ns.diff (Time_ns.now ()) t0 in
  _write_final_manifest ~manifest_path ~schema ~entries ~elapsed;
  _emit_final_progress ~output_dir ~symbols_total ~entries ~started_at;
  _verify_or_warn ~manifest_path

let command =
  Command.basic
    ~summary:"Build per-symbol snapshot files for the daily-snapshot warehouse"
    (let%map_open.Command universe_path =
       flag "universe-path" (required string)
         ~doc:
           "PATH Universe sexp (Pinned shape or analysis/data/universe \
            composition snapshot)"
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
     and start_date =
       flag "start-date"
         (optional (Command.Arg_type.create Date.of_string))
         ~doc:
           "YYYY-MM-DD Optional inclusive lower bound: drop each symbol's bars \
            before this date before building (default: full history). Pass the \
            backtest's WARMUP_START, not its start — indicators warm up over \
            in-window bars only, so earlier dates carry NaN indicators (same \
            contract as Csv_snapshot_builder's ~warmup_start)."
     and end_date =
       flag "end-date"
         (optional (Command.Arg_type.create Date.of_string))
         ~doc:
           "YYYY-MM-DD Optional inclusive upper bound: drop each symbol's bars \
            after this date before building (default: full history)."
     and incremental =
       flag "incremental" no_arg
         ~doc:
           "Skip symbols whose CSV mtime <= the existing manifest's csv_mtime"
     and progress_every =
       flag "progress-every"
         (optional_with_default _default_progress_every int)
         ~doc:
           (Printf.sprintf
              "N Emit progress.sexp every N symbols processed (default %d)"
              _default_progress_every)
     in
     fun () ->
       main ~universe_path ~csv_data_dir ~output_dir ~benchmark_symbol
         ~start_date ~end_date ~incremental ~progress_every ())

let () = Command_unix.run command
