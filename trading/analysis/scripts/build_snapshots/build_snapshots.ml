(** Phase B offline writer for the daily-snapshot streaming pipeline.

    Reads a universe sexp + per-symbol CSVs, runs {!Snapshot_pipeline.Pipeline}
    once per symbol, writes one snapshot file per symbol under the output
    directory, and produces [<output-dir>/manifest.sexp] indexing the result.
    The actual per-symbol build loop (windowing, incremental skip, manifest
    checkpointing, progress emission, verification) lives in {!Build_runner} so
    it is shared with {!Build_scenario_snapshots}; this module owns only the
    universe-file read and the CLI surface.

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
    [~warmup_start]. {!Build_scenario_snapshots} derives that warmup window
    automatically from a scenario. The durable fix is a Phase-F windowed/mmap
    decode in {!Daily_panels}; this flag is the cheap interim mitigation.

    Checkpointing: per-symbol atomic manifest update + periodic [progress.sexp]
    emission, both handled by {!Build_runner}. See
    [dev/plans/daily-snapshot-streaming-2026-04-27.md] §Phasing Phase B and
    [dev/plans/data-pipeline-automation-2026-05-03.md] for the contract. *)

open Core

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

let main ~universe_path ~csv_data_dir ~output_dir ~benchmark_symbol ~start_date
    ~end_date ~sketch_deep_days ~incremental ~progress_every () =
  let symbols = _load_universe ~universe_path in
  Build_runner.build ~symbols ~csv_data_dir ~output_dir ~benchmark_symbol
    ~start_date ~end_date ~sketch_deep_days ~incremental ~progress_every ()

(* Flag [~doc] strings are hoisted to top-level bindings so the [Command.basic]
   flag block below stays flat (one line per flag) — the multi-line doc text is
   the only deeply-indented content in this thin CLI shell, so lifting it keeps
   the file's structural nesting low. The build contract lives in
   {!Build_runner}. *)
let doc_universe_path =
  "PATH Universe sexp (Pinned shape or analysis/data/universe composition \
   snapshot)"

let doc_csv_data_dir = "PATH Directory containing per-symbol CSV history"

let doc_output_dir =
  "PATH Directory where snapshot files + manifest are written"

let doc_benchmark_symbol =
  "SYM Optional benchmark ticker for RS_line / Macro_composite (default: NaN \
   columns)"

let doc_start_date =
  "YYYY-MM-DD Optional inclusive lower bound: drop each symbol's bars before \
   this date before building (default: full history). Pass the backtest's \
   WARMUP_START, not its start — indicators warm up over in-window bars only, \
   so earlier dates carry NaN indicators (same contract as \
   Csv_snapshot_builder's ~warmup_start)."

let doc_end_date =
  "YYYY-MM-DD Optional inclusive upper bound: drop each symbol's bars after \
   this date before building (default: full history)."

let doc_sketch_deep_days =
  Printf.sprintf
    "N Calendar days of extra pre-START-DATE history fed only to the \
     SYMBOL.weekly side-table's weekly aggregation (resistance-v2 deep feed; \
     the 13 warmup-windowed .snap columns stay windowed to START-DATE). \
     Ignored without --start-date. Default %d."
    Build_runner.default_sketch_deep_days

let doc_incremental =
  "Skip symbols whose CSV mtime <= the existing manifest's csv_mtime"

let doc_progress_every =
  Printf.sprintf "N Emit progress.sexp every N symbols processed (default %d)"
    Build_runner.default_progress_every

let doc_emit_weekly_sidetable =
  "DEPRECATED no-op (sketch-v5 PR 4): the SYMBOL.weekly side-table is now \
   always emitted (it is the only overhead-supply representation), so this \
   flag has no effect; accepted for invocation-script back-compat"

let date_arg = Command.Param.optional (Command.Arg_type.create Date.of_string)

let command =
  Command.basic
    ~summary:"Build per-symbol snapshot files for the daily-snapshot warehouse"
    (let%map_open.Command universe_path =
       flag "universe-path" (required string) ~doc:doc_universe_path
     and csv_data_dir =
       flag "csv-data-dir" (required string) ~doc:doc_csv_data_dir
     and output_dir = flag "output-dir" (required string) ~doc:doc_output_dir
     and benchmark_symbol =
       flag "benchmark-symbol" (optional string) ~doc:doc_benchmark_symbol
     and start_date = flag "start-date" date_arg ~doc:doc_start_date
     and end_date = flag "end-date" date_arg ~doc:doc_end_date
     and sketch_deep_days =
       flag "sketch-deep-days"
         (optional_with_default Build_runner.default_sketch_deep_days int)
         ~doc:doc_sketch_deep_days
     and incremental = flag "incremental" no_arg ~doc:doc_incremental
     and progress_every =
       flag "progress-every"
         (optional_with_default Build_runner.default_progress_every int)
         ~doc:doc_progress_every
     and _emit_weekly_sidetable =
       flag "emit-weekly-sidetable" no_arg ~doc:doc_emit_weekly_sidetable
     in
     fun () ->
       main ~universe_path ~csv_data_dir ~output_dir ~benchmark_symbol
         ~start_date ~end_date ~sketch_deep_days ~incremental ~progress_every ())

let () = Command_unix.run command
