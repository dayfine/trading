(** Build the {e exact} snapshot warehouse a backtest scenario needs to run
    correctly in snapshot mode.

    [build_snapshots.exe] builds a warehouse over a universe file with whatever
    date window the operator passes. Getting either wrong silently corrupts a
    snapshot-mode run:

    - {b Warmup window.} The stage classifier is path-dependent on where the
      indicator series starts. Building over [scenario.start_date] (instead of
      [scenario.start_date - warmup_days]) shifts every weekly bar and changes
      results — an observed run flipped from the correct 41.3% to 81.5% return
      purely from a 2018 vs 2019-06 warehouse start.
    - {b Symbol completeness.} The runner loads bars for the universe {e plus}
      the primary index {e plus} the global macro indices {e plus} the 11 SPDR
      sector ETFs. Omit them and the macro / relative-strength columns are
      degenerate → the strategy produces {b 0 trades}.

    This tool derives both from the scenario itself, so a snapshot run matches a
    CSV-mode run by construction. It resolves the scenario's universe exactly as
    {!Scenario_runner} does (via {!Scenario_lib.Universe_file}), derives the
    warmup-windowed [all_symbols] set via {!Scenario_snapshot_plan.derive}
    (which reuses {!Backtest.Runner.warmup_days_for} +
    {!Backtest.Runner.all_snapshot_symbols}), and delegates the warehouse build
    to the shared {!Build_runner.build}. Unblocks running large-N (e.g. N=3000)
    goldens locally in snapshot mode. *)

open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module Plan = Scenario_snapshot_plan

(* Resolve the scenario's [universe_path] against [fixtures_root] and project it
   to its trading symbols, exactly as [Scenario_runner] does:
   [Universe_file.load] handles the Pinned shape, the composition-snapshot shape
   the goldens use, and the [Full_sector_map] sentinel.
   [to_sector_map_override] returns [None] only for [Full_sector_map] (the broad
   tier that defers to data/sectors.csv) — which this tool cannot window, so we
   exit with an actionable message rather than build an unbounded warehouse. *)
let _resolve_universe ~fixtures_root ~universe_path =
  let resolved = Filename.concat fixtures_root universe_path in
  match Universe_file.to_sector_map_override (Universe_file.load resolved) with
  | Some tbl -> Hashtbl.keys tbl |> List.sort ~compare:String.compare
  | None ->
      Printf.eprintf
        "build_scenario_snapshots: universe %s resolves to Full_sector_map \
         (the broad tier). This tool windows a bounded universe; point \
         -scenario at a scenario whose universe_path is a Pinned or \
         composition-snapshot universe instead.\n\
         %!"
        resolved;
      exit 1

let _log_plan (plan : Plan.t) ~scenario_path =
  Printf.eprintf
    "build_scenario_snapshots: %s -> %d symbols, window [%s, %s], benchmark %s\n\
     %!"
    scenario_path
    (List.length plan.all_symbols)
    (Date.to_string plan.warmup_start)
    (Date.to_string plan.end_date)
    plan.benchmark_symbol

let main ~scenario_path ~fixtures_root ~csv_data_dir ~output_dir ~incremental
    ~progress_every () =
  let scenario = Scenario.load scenario_path in
  let universe =
    _resolve_universe ~fixtures_root ~universe_path:scenario.universe_path
  in
  let plan = Plan.derive ~scenario ~universe in
  _log_plan plan ~scenario_path;
  Build_runner.build ~symbols:plan.all_symbols ~csv_data_dir ~output_dir
    ~benchmark_symbol:(Some plan.benchmark_symbol)
    ~start_date:(Some plan.warmup_start) ~end_date:(Some plan.end_date)
    ~incremental ~progress_every ()

let command =
  Command.basic
    ~summary:
      "Build the warmup-windowed all-symbols snapshot warehouse a scenario \
       needs to run in snapshot mode"
    (let%map_open.Command scenario_path =
       flag "scenario" (required string)
         ~doc:"PATH Scenario sexp (Scenario_lib.Scenario.t) to derive from"
     and fixtures_root =
       flag "fixtures-root" (required string)
         ~doc:
           "PATH Directory the scenario's universe_path is resolved against \
            (same as scenario_runner --fixtures-root)"
     and csv_data_dir =
       flag "csv-data-dir" (required string)
         ~doc:"PATH Directory containing per-symbol CSV history"
     and output_dir =
       flag "output-dir" (required string)
         ~doc:"PATH Directory where snapshot files + manifest are written"
     and incremental =
       flag "incremental" no_arg
         ~doc:
           "Skip symbols whose CSV mtime <= the existing manifest's csv_mtime"
     and progress_every =
       flag "progress-every"
         (optional_with_default Build_runner.default_progress_every int)
         ~doc:
           (Printf.sprintf
              "N Emit progress.sexp every N symbols processed (default %d)"
              Build_runner.default_progress_every)
     in
     fun () ->
       main ~scenario_path ~fixtures_root ~csv_data_dir ~output_dir ~incremental
         ~progress_every ())

let () = Command_unix.run command
