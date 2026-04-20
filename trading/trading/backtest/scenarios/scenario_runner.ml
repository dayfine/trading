(** Scenario runner — runs one or more backtest scenarios and compares actual
    metrics against the [expected] ranges declared in each scenario file.

    Usage: scenario_runner
    [--goldens-small | --goldens-broad | --goldens | --smoke | --dir <path>]
    [--parallel N]

    [--goldens-small] — small-universe goldens (~300 symbols; local-friendly).
    [--goldens-broad] — broad-universe goldens (full sector-map; nightly/GHA).
    [--goldens] — alias for [--goldens-small] for backwards compat.

    Reads all *.sexp files from the selected directory, runs each via
    {!Backtest.Runner.run_backtest}, prints a pass/fail table, and writes
    per-scenario output to [dev/backtest/scenarios-<timestamp>/<name>/].

    Scenarios run in parallel child processes (default 4). Each child is a fresh
    process — no shared mutable state leaks across scenarios. Children write
    [actual.sexp] alongside the other artefacts; the parent reads it back to
    compute checks and print the table in declaration order. *)

open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file

(* Universe resolution *)

let _fixtures_root () =
  let root = Data_path.default_data_dir () |> Fpath.parent |> Fpath.to_string in
  root ^ "trading/test_data/backtest_scenarios"

let _sector_map_of_universe_file path =
  (* Resolve the scenario's [universe_path] relative to the fixtures root,
     load it, and return an optional sector-map for [Backtest.Runner] to use
     as its universe. [None] means "use the full [data/sectors.csv]" (broad
     tier / pre-migration behaviour). *)
  let resolved = Filename.concat (_fixtures_root ()) path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

(* Actual metrics extracted from a run — serialized so the parent process
   can read back each child's result. *)

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  unrealized_pnl : float;
}
[@@deriving sexp]

let _actual_of_result (r : Backtest.Runner.result) =
  let open Trading_simulation_types.Metric_types in
  let s = r.summary in
  let get k = Map.find s.metrics k |> Option.value ~default:Float.nan in
  {
    total_return_pct =
      (s.final_portfolio_value -. s.initial_cash) /. s.initial_cash *. 100.0;
    total_trades = Float.of_int (List.length r.round_trips);
    win_rate = get WinRate;
    sharpe_ratio = get SharpeRatio;
    max_drawdown_pct = get MaxDrawdown;
    avg_holding_days = get AvgHoldingDays;
    unrealized_pnl = get UnrealizedPnl;
  }

(* Range checking *)

type check = { name : string; value : float; range : Scenario.range; ok : bool }

let _check_one name value (range : Scenario.range) =
  let ok = Scenario.in_range range value in
  { name; value; range; ok }

let _run_checks (a : actual) (e : Scenario.expected) =
  let base =
    [
      _check_one "total_return_pct" a.total_return_pct e.total_return_pct;
      _check_one "total_trades" a.total_trades e.total_trades;
      _check_one "win_rate" a.win_rate e.win_rate;
      _check_one "sharpe_ratio" a.sharpe_ratio e.sharpe_ratio;
      _check_one "max_drawdown_pct" a.max_drawdown_pct e.max_drawdown_pct;
      _check_one "avg_holding_days" a.avg_holding_days e.avg_holding_days;
    ]
  in
  match e.unrealized_pnl with
  | None -> base
  | Some range -> base @ [ _check_one "unrealized_pnl" a.unrealized_pnl range ]

let _failure_message checks =
  List.filter checks ~f:(fun c -> not c.ok)
  |> List.map ~f:(fun c ->
      if Float.(c.value < c.range.min_f) then
        sprintf "%s low (%.2f < %.2f)" c.name c.value c.range.min_f
      else sprintf "%s high (%.2f > %.2f)" c.name c.value c.range.max_f)
  |> String.concat ~sep:"; "

(* Output *)

let _print_header () =
  printf "%-28s %8s %7s %8s %8s   %s\n" "Scenario" "Return" "Trades" "WinRate"
    "MaxDD" "Result";
  printf "%s\n" (String.make 78 '-')

let _format_row (s : Scenario.t) (a : actual) checks =
  let all_ok = List.for_all checks ~f:(fun c -> c.ok) in
  let result_str =
    if all_ok then "PASS" else sprintf "FAIL (%s)" (_failure_message checks)
  in
  printf "%-28s %7.1f%% %7.0f %7.1f%% %7.1f%%   %s\n" s.name a.total_return_pct
    a.total_trades a.win_rate a.max_drawdown_pct result_str;
  all_ok

(* Directories *)

let _repo_root () =
  Data_path.default_data_dir () |> Fpath.parent |> Fpath.to_string

let _goldens_small_dir () =
  _repo_root () ^ "trading/test_data/backtest_scenarios/goldens-small"

let _goldens_broad_dir () =
  _repo_root () ^ "trading/test_data/backtest_scenarios/goldens-broad"

let _smoke_dir () = _repo_root () ^ "trading/test_data/backtest_scenarios/smoke"

let _list_scenario_files dir =
  Stdlib.Sys.readdir dir |> Array.to_list
  |> List.filter ~f:(fun f -> String.is_suffix f ~suffix:".sexp")
  |> List.sort ~compare:String.compare
  |> List.map ~f:(fun f -> Filename.concat dir f)

let _make_output_root () =
  let repo_root = _repo_root () in
  let now = Core_unix.gettimeofday () in
  let tm = Core_unix.localtime now in
  let ts =
    sprintf "%04d-%02d-%02d-%02d%02d%02d" (tm.tm_year + 1900) (tm.tm_mon + 1)
      tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let path = repo_root ^ "dev/backtest/scenarios-" ^ ts in
  Core_unix.mkdir_p path;
  path

let _scenario_dir ~output_root (s : Scenario.t) =
  Filename.concat output_root s.name

let _actual_path ~output_root (s : Scenario.t) =
  Filename.concat (_scenario_dir ~output_root s) "actual.sexp"

(* Run one scenario inside a child process *)

let _run_scenario_in_child ~output_root (s : Scenario.t) =
  eprintf "\n>>> Running %s: %s (%s to %s)\n%!" s.name s.description
    (Date.to_string s.period.start_date)
    (Date.to_string s.period.end_date);
  let scenario_dir = _scenario_dir ~output_root s in
  Core_unix.mkdir_p scenario_dir;
  let sector_map_override = _sector_map_of_universe_file s.universe_path in
  let result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ?loader_strategy:s.loader_strategy ()
  in
  Backtest.Result_writer.write ~output_dir:scenario_dir result;
  let a = _actual_of_result result in
  Sexp.save_hum (_actual_path ~output_root s) (sexp_of_actual a)

(* Fork-based worker pool. Scenarios run in parallel child processes up to
   [parallel] at a time. *)

let _fork_scenario ~output_root (s : Scenario.t) =
  match Core_unix.fork () with
  | `In_the_child -> (
      try
        _run_scenario_in_child ~output_root s;
        Stdlib.exit 0
      with e ->
        eprintf "Scenario %s crashed: %s\n%!" s.name (Exn.to_string e);
        Stdlib.exit 1)
  | `In_the_parent pid -> pid

type _child_status = Succeeded | Crashed

let _await_one running =
  let _, pid = Queue.dequeue_exn running in
  match Core_unix.waitpid pid with Ok () -> Succeeded | Error _ -> Crashed

let _run_scenarios_parallel ~output_root ~parallel (scenarios : Scenario.t list)
    =
  let running = Queue.create () in
  let statuses = Hashtbl.create (module String) in
  let reap () =
    let pair = Queue.peek_exn running in
    let s, _ = pair in
    let status = _await_one running in
    Hashtbl.set statuses ~key:s.Scenario.name ~data:status
  in
  List.iter scenarios ~f:(fun s ->
      if Queue.length running >= parallel then reap ();
      let pid = _fork_scenario ~output_root s in
      Queue.enqueue running (s, pid));
  while not (Queue.is_empty running) do
    reap ()
  done;
  List.map scenarios ~f:(fun s ->
      let status =
        Hashtbl.find statuses s.Scenario.name |> Option.value ~default:Crashed
      in
      (s, status))

(* Parent-side: read back the child's actual.sexp and run checks *)

let _load_actual ~output_root (s : Scenario.t) =
  try Some (actual_of_sexp (Sexp.load_sexp (_actual_path ~output_root s)))
  with _ -> None

let _print_crashed_row (s : Scenario.t) =
  printf "%-28s %8s %7s %8s %8s   %s\n" s.name "-" "-" "-" "-"
    "FAIL (scenario crashed or did not write actual.sexp)"

let _process_result ~output_root (s, status) =
  match status with
  | Crashed ->
      _print_crashed_row s;
      false
  | Succeeded -> (
      match _load_actual ~output_root s with
      | None ->
          _print_crashed_row s;
          false
      | Some a ->
          let checks = _run_checks a s.expected in
          _format_row s a checks)

(* CLI *)

type _cli_args = { dir : string; parallel : int }

let _default_parallel = 4

let _usage () =
  eprintf
    "Usage: scenario_runner [--goldens-small | --goldens-broad | --goldens | \
     --smoke | --dir <path>] [--parallel N]\n";
  Stdlib.exit 1

let _parse_flag args =
  let rec loop args dir parallel =
    match args with
    | [] ->
        let dir = Option.value dir ~default:(_goldens_small_dir ()) in
        { dir; parallel = Option.value parallel ~default:_default_parallel }
    | "--goldens-small" :: rest ->
        loop rest (Some (_goldens_small_dir ())) parallel
    | "--goldens-broad" :: rest ->
        loop rest (Some (_goldens_broad_dir ())) parallel
    | "--goldens" :: rest -> loop rest (Some (_goldens_small_dir ())) parallel
    | "--smoke" :: rest -> loop rest (Some (_smoke_dir ())) parallel
    | "--dir" :: path :: rest -> loop rest (Some path) parallel
    | "--parallel" :: n :: rest -> loop rest dir (Some (Int.of_string n))
    | _ -> _usage ()
  in
  loop args None None

let _parse_args () =
  let argv = Sys.get_argv () in
  _parse_flag (List.tl_exn (Array.to_list argv))

let () =
  let { dir; parallel } = _parse_args () in
  let files = _list_scenario_files dir in
  if List.is_empty files then (
    eprintf "No .sexp scenario files found in %s\n" dir;
    Stdlib.exit 1);
  let parallel = min parallel (List.length files) in
  eprintf "Loading %d scenarios from %s (parallel=%d)\n%!" (List.length files)
    dir parallel;
  let scenarios = List.map files ~f:Scenario.load in
  let output_root = _make_output_root () in
  eprintf "Output root: %s\n%!" output_root;
  let results = _run_scenarios_parallel ~output_root ~parallel scenarios in
  _print_header ();
  let pass_flags = List.map results ~f:(_process_result ~output_root) in
  let all_pass = List.for_all pass_flags ~f:Fn.id in
  let n_pass = List.count pass_flags ~f:Fn.id in
  let n_total = List.length pass_flags in
  printf "\n%d/%d scenarios passed.\n" n_pass n_total;
  if not all_pass then Stdlib.exit 1
