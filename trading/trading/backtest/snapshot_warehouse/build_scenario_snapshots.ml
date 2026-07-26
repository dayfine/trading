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

(* Load a symbol's windowed adjusted-close series for twin detection. Returns
   [None] when the CSV is missing / unreadable / empty in-window (that symbol
   simply cannot be a twin candidate). *)
let _load_series ~data_dir ~warmup_start ~end_date symbol =
  let open Option.Let_syntax in
  let%bind storage = Result.ok (Csv.Csv_storage.create ~data_dir symbol) in
  let%bind bars = Result.ok (Csv.Csv_storage.get storage ()) in
  match Bar_window.filter ~start:warmup_start ~end_:end_date bars with
  | [] -> None
  | windowed ->
      let closes =
        List.map windowed ~f:(fun (b : Types.Daily_price.t) ->
            (b.date, b.adjusted_close))
        |> Array.of_list
      in
      Array.sort closes ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2);
      let last_date, _ = closes.(Array.length closes - 1) in
      Some { Twin_detector.symbol; data_end = last_date; closes }

let _write_twin_report ~output_dir report =
  (if not (Stdlib.Sys.file_exists output_dir) then
     try Stdlib.Sys.mkdir output_dir 0o755 with _ -> ());
  let path = Filename.concat output_dir "rename_twin_report.txt" in
  let text = Twin_detector.render report in
  (try Out_channel.write_all path ~data:(text ^ "\n")
   with Sys_error msg -> Printf.eprintf "twin report write failed: %s\n%!" msg);
  Printf.eprintf "%s\n%!" text

(* When armed, detect rename-twins across [all_symbols] and drop the losing
   legs; emit the sidecar report. Default-off config → [all_symbols] unchanged,
   no report. *)
let _dedupe_symbols ~config ~data_dir ~warmup_start ~end_date ~output_dir
    all_symbols =
  if not config.Twin_detector.Config.enabled then all_symbols
  else begin
    let series =
      List.filter_map all_symbols
        ~f:(_load_series ~data_dir ~warmup_start ~end_date)
    in
    let report = Twin_detector.detect config series in
    _write_twin_report ~output_dir report;
    Twin_detector.survivors report ~all_symbols
  end

let main ~scenario_path ~fixtures_root ~csv_data_dir ~output_dir
    ~sketch_deep_days ~incremental ~progress_every ~twin_config () =
  let scenario = Scenario.load scenario_path in
  let universe =
    _resolve_universe ~fixtures_root ~universe_path:scenario.universe_path
  in
  let plan = Plan.derive ~scenario ~universe in
  _log_plan plan ~scenario_path;
  let symbols =
    _dedupe_symbols ~config:twin_config ~data_dir:(Fpath.v csv_data_dir)
      ~warmup_start:plan.warmup_start ~end_date:plan.end_date ~output_dir
      plan.all_symbols
  in
  Build_runner.build ~symbols ~csv_data_dir ~output_dir
    ~benchmark_symbol:(Some plan.benchmark_symbol)
    ~start_date:(Some plan.warmup_start) ~end_date:(Some plan.end_date)
    ~sketch_deep_days ~incremental ~progress_every ()

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
     and sketch_deep_days =
       flag "sketch-deep-days"
         (optional_with_default Build_runner.default_sketch_deep_days int)
         ~doc:
           (Printf.sprintf
              "N Calendar days of extra pre-warmup history fed only to the \
               SYMBOL.weekly side-table's weekly aggregation (resistance-v2 \
               deep feed; the 13 warmup-windowed .snap columns are unchanged). \
               Default %d."
              Build_runner.default_sketch_deep_days)
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
     and _emit_weekly_sidetable =
       flag "emit-weekly-sidetable" no_arg
         ~doc:
           "DEPRECATED no-op (sketch-v5 PR 4): the SYMBOL.weekly side-table is \
            now always emitted (it is the only overhead-supply \
            representation), so this flag has no effect; accepted for \
            invocation-script back-compat"
     and dedupe_rename_twins =
       flag "dedupe-rename-twins" no_arg
         ~doc:
           "Drop rename-twin duplicate legs (same series under old+new ticker) \
            before building; writes rename_twin_report.txt. Default off — \
            existing warehouses stay reproducible."
     and twin_min_overlap_days =
       flag "twin-min-overlap-days"
         (optional_with_default Twin_detector.Config.default.min_overlap_days
            int)
         ~doc:"N Min shared trading days for a twin match"
     and twin_match_fraction =
       flag "twin-match-fraction"
         (optional_with_default Twin_detector.Config.default.match_fraction
            float)
         ~doc:"F Min fraction of overlapping days with near-identical closes"
     and twin_close_epsilon =
       flag "twin-close-epsilon"
         (optional_with_default Twin_detector.Config.default.close_epsilon float)
         ~doc:"E Relative tolerance for a single-day close match (basis=levels)"
     and twin_basis =
       flag "twin-basis"
         (optional_with_default "levels" string)
         ~doc:
           "B Comparison basis: levels (default, adjusted-close levels) or \
            returns (consecutive daily returns — catches renames whose feeds \
            carry different adjustment bases)"
     and twin_ret_epsilon =
       flag "twin-ret-epsilon"
         (optional_with_default Twin_detector.Config.default.ret_epsilon float)
         ~doc:
           "E Absolute tolerance on the daily-return difference (basis=returns)"
     in
     fun () ->
       let basis =
         match String.lowercase twin_basis with
         | "levels" -> Twin_detector.Config.Levels
         | "returns" -> Twin_detector.Config.Returns
         | other ->
             failwithf "unknown -twin-basis %s (expected levels|returns)" other
               ()
       in
       let twin_config =
         {
           Twin_detector.Config.enabled = dedupe_rename_twins;
           min_overlap_days = twin_min_overlap_days;
           match_fraction = twin_match_fraction;
           close_epsilon = twin_close_epsilon;
           basis;
           ret_epsilon = twin_ret_epsilon;
           prefilter_rel_tol = Twin_detector.Config.default.prefilter_rel_tol;
         }
       in
       main ~scenario_path ~fixtures_root ~csv_data_dir ~output_dir
         ~sketch_deep_days ~incremental ~progress_every ~twin_config ())

let () = Command_unix.run command
