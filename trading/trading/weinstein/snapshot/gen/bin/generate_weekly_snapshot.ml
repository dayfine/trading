(** [generate_weekly_snapshot] CLI — produce one weekly snapshot from cached
    bars (M6.6 / Initiative A).

    Usage:
    {[
      generate_weekly_snapshot \
        --as-of 2023-09-29 \
        --universe path/to/universe.sexp \
        --bars path/to/bars-dir \
        --snapshot-dir dev/weekly-picks \
        [--system-version <tag>] \
        [--no-validate]
    ]}

    Loads the pinned universe, runs the existing Weinstein screener cascade via
    {!Weekly_snapshot_generator.generate}, and writes the assembled
    {!Weekly_snapshot.t} to [<snapshot-dir>/<system-version>/<as-of>.sexp] via
    {!Snapshot_writer.write_to_file}. Prints the written path on success; exits
    non-zero on any I/O or universe error.

    {1 Self-check (issue #2122 slice a, warn-first)}

    Unless [--no-validate] is passed, the assembled record is run through
    {!Snapshot_validator} and the findings are printed {b on stderr}. This is
    {b observation only}:

    - the exit code is unchanged — an [Error]-level finding still exits 0,
    - the written artifact is unchanged — validation reads, never edits,
    - {b stdout is unchanged} — it still carries only the written path, because
      callers pipe it.

    Escalating an [Error] finding to a non-zero exit is a deliberate later
    decision, not an oversight: the first honest live run needs the checks
    {e visible} before they are allowed to fail a run.

    Thresholds come from the {b same} config the generator screened with (i.e.
    from [--config-overrides]), never from the validator's own defaults — a
    validator judging the artifact under thresholds other than the ones that
    produced it emits confident wrong findings. The bar-dependent checks run
    against the generator's own bar reader. The optional [risk_budget] check is
    {b not} run (see [_validation_skipped_note]).

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

module Live_portfolio = Weinstein_snapshot_gen.Live_portfolio

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

(* Default cash for the template portfolio used when no --portfolio file is
   given: candidates are still sized (so the report shows an executable shape)
   but stamped UNSIZED. Matches the committed template's placeholder cash. *)
let _template_cash = 100_000.0

(* The live portfolio to size + report against, plus whether it is the template
   placeholder. With --portfolio, load the file (a parse error aborts). Without
   it, use an empty template book at [_template_cash] and flag it placeholder. *)
let _live_portfolio ~portfolio_path ~as_of : Live_portfolio.t * bool =
  match portfolio_path with
  | None ->
      ({ Live_portfolio.cash = _template_cash; as_of; positions = [] }, true)
  | Some path -> (
      match Live_portfolio.load ~path with
      | Ok p -> (p, false)
      | Error err ->
          eprintf "Failed to load portfolio %s: %s\n" path
            (Error.to_string_hum err);
          exit 2)

(* ---- Self-check (issue #2122 slice a) ---------------------------------- *)

(* The risk-budget check needs the per-run risk budget (risk_per_trade_pct x
   portfolio_value). [portfolio_value] is computed inside
   [Weekly_snapshot_generator.generate] and is not returned, so re-deriving it
   here would duplicate the generator's own formula and could silently drift
   from it. Not running the check and saying so is honest; running it against a
   re-derived budget is not. Tracked in dev/status/weekly-snapshot.md. *)
let _validation_skipped_note =
  "snapshot self-check: risk_budget check NOT RUN (the sizing portfolio_value \
   is internal to the generator; re-deriving it here could drift).\n"

let _validation_header ~(config : Weinstein_strategy.config) =
  Printf.sprintf
    "snapshot self-check (warn-first, #2122): thresholds band=%.2f max=%.2f \
     (from the screening config); bar-dependent checks ON.\n"
    config.entry_through_band_pct config.entry_extension_max_pct

(* Run every {!Snapshot_validator} check over the assembled record and print the
   findings on stderr. Returns unit: the exit code and the written artifact are
   deliberately untouched (warn-first). stdout is never written to here. *)
let _validate_and_report ~(config : Weinstein_strategy.config) ~bar_reader
    ~as_of snapshot =
  let bars_for ~symbol = Bar_reader.daily_bars_for bar_reader ~symbol ~as_of in
  let findings =
    Snapshot_validator.validate ~through_band_pct:config.entry_through_band_pct
      ~extension_max_pct:config.entry_extension_max_pct ~bars_for snapshot
  in
  eprintf "%s" (_validation_header ~config);
  eprintf "%s" (Snapshot_validator.to_report findings);
  eprintf "%s" _validation_skipped_note

let _run ~as_of ~universe_path ~bar_source ~snapshot_dir ~system_version
    ~index_symbol ~config_overrides_path ~portfolio_path ~validate () =
  let ticker_sectors = _ticker_sectors_of_universe universe_path in
  let config =
    _config_for ~ticker_sectors ~index_symbol ~config_overrides_path
  in
  let bar_reader =
    _build_bar_reader ~bar_source ~as_of ~ticker_sectors ~config
  in
  let live_portfolio, portfolio_is_placeholder =
    _live_portfolio ~portfolio_path ~as_of
  in
  let snapshot =
    Weekly_snapshot_generator.generate
      {
        config;
        system_version;
        as_of;
        bar_reader;
        ticker_sectors;
        live_portfolio;
        portfolio_is_placeholder;
      }
  in
  if validate then _validate_and_report ~config ~bar_reader ~as_of snapshot;
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
     and portfolio_path =
       flag "--portfolio"
         (optional Filename_unix.arg_type)
         ~doc:
           "PATH Live-portfolio sexp (Live_portfolio.t: cash + held \
            positions). When given, held positions are priced + reported and \
            long candidates are sized against real cash/exposure. Without it, \
            candidates are sized against a $100k template book and stamped \
            UNSIZED. Template: dev/weekly-picks/portfolio.sexp"
     and no_validate =
       flag "--no-validate" no_arg
         ~doc:
           " Skip the post-generate Snapshot_validator self-check. The check \
            is ON by default and prints findings on stderr WITHOUT changing \
            the exit code, stdout, or the written artifact; this flag exists \
            as an escape hatch for bulk sweeps (the bar-dependent checks \
            re-read bars per candidate) and for the case where the validator \
            itself misbehaves on a live Friday."
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
         ~index_symbol ~config_overrides_path ~portfolio_path
         ~validate:(not no_validate) ())

let () = Command_unix.run command
