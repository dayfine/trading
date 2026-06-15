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

    Loads the pinned universe + its cached daily bars, runs the existing
    Weinstein screener cascade via {!Weekly_snapshot_generator.generate}, and
    writes the assembled {!Weekly_snapshot.t} to
    [<snapshot-dir>/<system-version>/<as-of>.sexp] via
    {!Snapshot_writer.write_to_file}. Prints the written path on success; exits
    non-zero on any I/O or universe error. *)

open Core
open Weinstein_snapshot
module Bar_reader = Weinstein_strategy.Bar_reader
module Universe_file = Scenario_lib.Universe_file

module Weekly_snapshot_generator =
  Weinstein_snapshot_gen.Weekly_snapshot_generator

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

let _build_bar_reader ~bars_dir ~ticker_sectors ~config =
  let symbols = _symbols_to_load ~ticker_sectors ~config in
  let symbol_bars =
    List.map symbols ~f:(fun s -> (s, _load_bars ~bars_dir s))
  in
  Bar_reader.of_in_memory_bars symbol_bars

let _config_for ~ticker_sectors ~index_symbol : Weinstein_strategy.config =
  let universe = List.map ticker_sectors ~f:fst in
  let base = Weinstein_strategy.default_config ~universe ~index_symbol in
  { base with sector_etfs = Weinstein_strategy.Macro_inputs.spdr_sector_etfs }

let _run ~as_of ~universe_path ~bars_dir ~snapshot_dir ~system_version
    ~index_symbol () =
  let ticker_sectors = _ticker_sectors_of_universe universe_path in
  let config = _config_for ~ticker_sectors ~index_symbol in
  let bar_reader = _build_bar_reader ~bars_dir ~ticker_sectors ~config in
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
         (required Filename_unix.arg_type)
         ~doc:"PATH CSV-storage bars directory"
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
     in
     fun () ->
       _run ~as_of ~universe_path ~bars_dir ~snapshot_dir ~system_version
         ~index_symbol ())

let () = Command_unix.run command
