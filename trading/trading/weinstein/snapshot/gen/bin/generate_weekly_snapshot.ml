(** [generate_weekly_snapshot] CLI — produce one weekly snapshot from cached
    bars (M6.6 / Initiative A).

    Usage:
    {[
      generate_weekly_snapshot \
        --as-of 2023-09-29 \
        --universe path/to/universe.sexp \
        --bars path/to/bars-dir \
        --snapshot-dir dev/weekly-picks \
        [--system-version <tag>]
    ]}

    Loads the pinned universe, runs the existing Weinstein screener cascade via
    {!Weekly_snapshot_generator.generate}, and writes the assembled
    {!Weekly_snapshot.t} to [<snapshot-dir>/<system-version>/<as-of>.sexp] via
    {!Snapshot_writer.write_to_file}. Prints the written path on success; exits
    non-zero on any I/O or universe error.

    The bar source is selected by exactly one of two mutually-exclusive flags:

    - [--bars DIR] — the legacy CSV path: load every symbol's cached daily bars
      into memory ([Bar_reader.of_in_memory_bars], which materialises a tmp
      snapshot on every run). Correct but slow — unusable for a multi-week
      sweep.
    - [--bars-snapshot-dir DIR] — the fast path: stream rows on demand from a
      pre-built snapshot warehouse ([Snapshot_warehouse_reader.build]), the same
      reader the backtest runners use. Build a warehouse with the
      [build_snapshots] tool. *)

open Core
open Weinstein_snapshot
module Bar_reader = Weinstein_strategy.Bar_reader
module Universe_file = Scenario_lib.Universe_file

module Weekly_snapshot_generator =
  Weinstein_snapshot_gen.Weekly_snapshot_generator

module Snapshot_warehouse_reader =
  Weinstein_snapshot_gen.Snapshot_warehouse_reader

(* Daily-history warmup the snapshot-backed reader's trading-day calendar must
   span before [as_of]. Two trading years comfortably covers the screener's
   longest daily lookback (the 30-week MA over daily bars plus the base /
   breakout-event windows). *)
let _warmup_days = 730

(* When the resistance-history feed is armed ([resistance_lookback_bars > 0],
   typically 520 weekly bars ~= 10y), the warehouse reader must load enough
   daily history to materialise that deeper weekly view — otherwise the live
   weekly review keeps producing CWST-class false-virgin text off ~104 weekly
   bars. 7 calendar days per weekly bar + a small holiday/alignment buffer. *)
let _warmup_days_for ~(config : Weinstein_strategy.config) =
  Int.max _warmup_days ((config.resistance_lookback_bars * 7) + 30)

(* Which bar backend to use, parsed from the mutually-exclusive
   [--bars] / [--bars-snapshot-dir] flags. *)
type bar_source = Csv_dir of string | Warehouse_dir of string

(* Load daily bars for one symbol from the CSV-storage layout. Mirrors
   [trace_picks]'s loader: fail-soft to [] so a missing symbol degrades to "no
   bars" rather than aborting the whole run. *)
let _load_bars ~bars_dir symbol : Types.Daily_price.t list =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v bars_dir) symbol with
  | Error _ -> []
  | Ok storage -> (
      match Csv.Csv_storage.get storage () with
      | Error _ -> []
      | Ok bars -> bars)

(* The pinned universe as [(ticker, sector)] pairs. [Full_sector_map] is not
   self-contained (it relies on data/sectors.csv) — reject it with a clear
   message rather than silently screening an empty universe. *)
let _ticker_sectors_of_universe path : (string * string) list =
  match Universe_file.load path with
  | Pinned entries ->
      List.map entries ~f:(fun (e : Universe_file.pinned_entry) ->
          (e.symbol, e.sector))
  | Full_sector_map ->
      eprintf
        "Universe %s is Full_sector_map; generate_weekly_snapshot requires a \
         Pinned universe (explicit (symbol sector) list).\n"
        path;
      exit 2

(* All symbols whose bars we must load: the universe tickers, every sector ETF,
   and the primary index. Deduplicated. *)
let _symbols_to_load ~ticker_sectors ~(config : Weinstein_strategy.config) =
  let tickers = List.map ticker_sectors ~f:fst in
  let etfs = List.map config.sector_etfs ~f:fst in
  (config.indices.primary :: etfs) @ tickers
  |> List.dedup_and_sort ~compare:String.compare

let _build_csv_bar_reader ~bars_dir ~ticker_sectors ~config =
  let symbols = _symbols_to_load ~ticker_sectors ~config in
  let symbol_bars =
    List.map symbols ~f:(fun s -> (s, _load_bars ~bars_dir s))
  in
  Bar_reader.of_in_memory_bars symbol_bars

(* Build the bar reader for the selected backend. The CSV path materialises a
   tmp snapshot from in-memory bars; the warehouse path streams from a pre-built
   on-disk snapshot, passing a real trading-day calendar for deterministic
   windows. *)
let _build_bar_reader ~bar_source ~as_of ~ticker_sectors ~config =
  match bar_source with
  | Csv_dir bars_dir -> _build_csv_bar_reader ~bars_dir ~ticker_sectors ~config
  | Warehouse_dir warehouse_dir ->
      Snapshot_warehouse_reader.build ~warehouse_dir ~as_of
        ~warmup_days:(_warmup_days_for ~config) ()

let _config_for ~ticker_sectors ~index_symbol ~config_overrides_path :
    Weinstein_strategy.config =
  let universe = List.map ticker_sectors ~f:fst in
  let base = Weinstein_strategy.default_config ~universe ~index_symbol in
  let config =
    { base with sector_etfs = Weinstein_strategy.Macro_inputs.spdr_sector_etfs }
  in
  match config_overrides_path with
  | None -> config
  | Some overrides_path ->
      Snapshot_config_overrides.Config_overrides_loader.load_and_apply
        ~overrides_path config

let _run ~as_of ~universe_path ~bar_source ~snapshot_dir ~system_version
    ~index_symbol ~config_overrides_path () =
  let ticker_sectors = _ticker_sectors_of_universe universe_path in
  let config =
    _config_for ~ticker_sectors ~index_symbol ~config_overrides_path
  in
  let bar_reader =
    _build_bar_reader ~bar_source ~as_of ~ticker_sectors ~config
  in
  let snapshot =
    Weekly_snapshot_generator.generate
      {
        config;
        system_version;
        as_of;
        bar_reader;
        ticker_sectors;
        held_positions = [];
      }
  in
  match
    Snapshot_writer.write_to_file ~root:snapshot_dir ~system_version snapshot
  with
  | Ok path -> printf "Wrote %s\n" path
  | Error err ->
      eprintf "Failed to write snapshot: %s\n" (Status.show err);
      exit 1

let command =
  Command.basic
    ~summary:
      "Generate one weekly snapshot from cached bars: run the Weinstein \
       screener cascade as of a date and write the ranked picks to \
       <snapshot-dir>/<system-version>/<as-of>.sexp."
    (let%map_open.Command as_of =
       flag "--as-of"
         (required (Command.Arg_type.create Date.of_string))
         ~doc:"DATE As-of (Friday-close) date in YYYY-MM-DD form"
     and universe_path =
       flag "--universe"
         (required Filename_unix.arg_type)
         ~doc:"PATH Pinned universe sexp ((symbol sector) list)"
     and bars_dir =
       flag "--bars"
         (optional Filename_unix.arg_type)
         ~doc:
           "PATH CSV-storage bars directory (mutually exclusive with \
            --bars-snapshot-dir)"
     and bars_snapshot_dir =
       flag "--bars-snapshot-dir"
         (optional Filename_unix.arg_type)
         ~doc:
           "PATH Pre-built snapshot warehouse directory, the fast input path \
            (mutually exclusive with --bars)"
     and snapshot_dir =
       flag "--snapshot-dir"
         (required Filename_unix.arg_type)
         ~doc:"PATH Root output dir (snapshot lands under <dir>/<version>/)"
     and system_version =
       flag "--system-version"
         (optional_with_default "dev" string)
         ~doc:"TAG System-version tag (default: dev)"
     and index_symbol =
       flag "--index-symbol"
         (optional_with_default "GSPC.INDX" string)
         ~doc:"SYM Primary benchmark index symbol (default: GSPC.INDX)"
     and config_overrides_path =
       flag "--config-overrides"
         (optional Filename_unix.arg_type)
         ~doc:
           "PATH Sexp file of config overlays (scenario config_overrides \
            shape) applied onto the default config; unknown keys fail loudly. \
            The live weekly-review arming config lives at \
            dev/weekly-picks/live-config-overrides.sexp"
     in
     fun () ->
       let bar_source =
         match (bars_dir, bars_snapshot_dir) with
         | Some d, None -> Csv_dir d
         | None, Some d -> Warehouse_dir d
         | None, None ->
             eprintf
               "Exactly one of --bars / --bars-snapshot-dir is required; \
                neither was given.\n";
             exit 2
         | Some _, Some _ ->
             eprintf
               "--bars and --bars-snapshot-dir are mutually exclusive; pass \
                only one.\n";
             exit 2
       in
       _run ~as_of ~universe_path ~bar_source ~snapshot_dir ~system_version
         ~index_symbol ~config_overrides_path ())

let () = Command_unix.run command
