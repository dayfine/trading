(** Scenario runner — runs one or more backtest scenarios and compares actual
    metrics against the [expected] ranges declared in each scenario file.

    Usage: scenario_runner [--goldens | --smoke | --dir <path>]

    Reads all *.sexp files from the selected directory, runs each via
    {!Backtest_runner_lib.run_backtest}, prints a pass/fail table, and writes
    per-scenario output to [dev/backtest/scenarios-<timestamp>/<name>/].

    Scenarios are executed sequentially with a fresh strategy per scenario
    (important for isolation — no shared mutable state leaks across runs). *)

open Core

(* ------------------------------------------------------------------ *)
(* Scenario data model                                                 *)
(* ------------------------------------------------------------------ *)

type range = { min_f : float; max_f : float }

type expected = {
  total_return_pct : range;
  total_trades : range;
  win_rate : range;
  sharpe_ratio : range;
  max_drawdown_pct : range;
  avg_holding_days : range;
}

type scenario = {
  name : string;
  description : string;
  start_date : Date.t;
  end_date : Date.t;
  config_overrides : Sexp.t list;
      (** Partial config sexps deep-merged into the default Weinstein config, in
          order. Empty list means the default config. *)
  expected : expected;
}

(* ------------------------------------------------------------------ *)
(* Sexp parsing                                                        *)
(* ------------------------------------------------------------------ *)

let _atom = function
  | Sexp.Atom s -> s
  | other -> failwith (sprintf "expected atom, got: %s" (Sexp.to_string other))

let _find_field fields key =
  List.find_map fields ~f:(function
    | Sexp.List (Sexp.Atom k :: rest) when String.equal k key -> Some rest
    | _ -> None)

let _find_field_exn fields key =
  match _find_field fields key with
  | Some v -> v
  | None -> failwith (sprintf "missing required field: %s" key)

let _single = function
  | [ v ] -> v
  | _ -> failwith "expected single value in field"

let _parse_range sexp =
  match sexp with
  | Sexp.List fields ->
      let min_f =
        _find_field_exn fields "min" |> _single |> _atom |> Float.of_string
      in
      let max_f =
        _find_field_exn fields "max" |> _single |> _atom |> Float.of_string
      in
      { min_f; max_f }
  | _ -> failwith (sprintf "invalid range sexp: %s" (Sexp.to_string sexp))

let _range_field fields key =
  _find_field_exn fields key |> _single |> _parse_range

let _build_expected_from_fields fields =
  {
    total_return_pct = _range_field fields "total_return_pct";
    total_trades = _range_field fields "total_trades";
    win_rate = _range_field fields "win_rate";
    sharpe_ratio = _range_field fields "sharpe_ratio";
    max_drawdown_pct = _range_field fields "max_drawdown_pct";
    avg_holding_days = _range_field fields "avg_holding_days";
  }

let _parse_expected = function
  | Sexp.List fields -> _build_expected_from_fields fields
  | other ->
      failwith (sprintf "invalid expected sexp: %s" (Sexp.to_string other))

let _parse_period sexp =
  match sexp with
  | Sexp.List fields ->
      let sd = _find_field_exn fields "start_date" |> _single |> _atom in
      let ed = _find_field_exn fields "end_date" |> _single |> _atom in
      (Date.of_string sd, Date.of_string ed)
  | _ -> failwith "invalid period sexp"

(** Parse [(config_overrides ...)] — a list of partial config sexps, each to be
    deep-merged into the default config in order. An empty list means "use
    default config". *)
let _parse_overrides = function
  | Sexp.List entries -> entries
  | other ->
      failwith
        (sprintf "invalid config_overrides sexp: %s" (Sexp.to_string other))

let _load_scenario path =
  let sexp = Sexp.load_sexp path in
  match sexp with
  | Sexp.List fields ->
      let name = _find_field_exn fields "name" |> _single |> _atom in
      let description =
        _find_field_exn fields "description" |> _single |> _atom
      in
      let start_date, end_date =
        _find_field_exn fields "period" |> _single |> _parse_period
      in
      let config_overrides =
        _find_field_exn fields "config_overrides" |> _single |> _parse_overrides
      in
      let expected =
        _find_field_exn fields "expected" |> _single |> _parse_expected
      in
      { name; description; start_date; end_date; config_overrides; expected }
  | _ -> failwith (sprintf "Cannot parse scenario file: %s" path)

(* ------------------------------------------------------------------ *)
(* Scenario directory resolution                                       *)
(* ------------------------------------------------------------------ *)

let _repo_root () =
  Data_path.default_data_dir () |> Fpath.parent |> Fpath.to_string

let _goldens_dir () =
  _repo_root () ^ "trading/test_data/backtest_scenarios/goldens"

let _smoke_dir () = _repo_root () ^ "trading/test_data/backtest_scenarios/smoke"

let _list_scenario_files dir =
  Stdlib.Sys.readdir dir |> Array.to_list
  |> List.filter ~f:(fun f -> String.is_suffix f ~suffix:".sexp")
  |> List.sort ~compare:String.compare
  |> List.map ~f:(fun f -> Filename.concat dir f)

(* ------------------------------------------------------------------ *)
(* Metric extraction                                                   *)
(* ------------------------------------------------------------------ *)

let _initial_cash = 1_000_000.0

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
}

let _actual_of_result (r : Backtest_runner_lib.result) =
  let open Trading_simulation_types.Metric_types in
  let get k = Map.find r.metrics k |> Option.value ~default:Float.nan in
  {
    total_return_pct =
      (r.final_value -. _initial_cash) /. _initial_cash *. 100.0;
    total_trades = Float.of_int (List.length r.round_trips);
    win_rate = get WinRate;
    sharpe_ratio = get SharpeRatio;
    max_drawdown_pct = get MaxDrawdown;
    avg_holding_days = get AvgHoldingDays;
  }

(* ------------------------------------------------------------------ *)
(* Range checking                                                      *)
(* ------------------------------------------------------------------ *)

type check = { name : string; value : float; range : range; ok : bool }

let _check_one name value range =
  let ok = Float.(value >= range.min_f && value <= range.max_f) in
  { name; value; range; ok }

let _run_checks (a : actual) (e : expected) =
  [
    _check_one "total_return_pct" a.total_return_pct e.total_return_pct;
    _check_one "total_trades" a.total_trades e.total_trades;
    _check_one "win_rate" a.win_rate e.win_rate;
    _check_one "sharpe_ratio" a.sharpe_ratio e.sharpe_ratio;
    _check_one "max_drawdown_pct" a.max_drawdown_pct e.max_drawdown_pct;
    _check_one "avg_holding_days" a.avg_holding_days e.avg_holding_days;
  ]

let _failure_message checks =
  List.filter checks ~f:(fun c -> not c.ok)
  |> List.map ~f:(fun c ->
      if Float.(c.value < c.range.min_f) then
        sprintf "%s low (%.2f < %.2f)" c.name c.value c.range.min_f
      else sprintf "%s high (%.2f > %.2f)" c.name c.value c.range.max_f)
  |> String.concat ~sep:"; "

(* ------------------------------------------------------------------ *)
(* Output                                                              *)
(* ------------------------------------------------------------------ *)

let _print_header () =
  printf "%-28s %8s %7s %8s %8s   %s\n" "Scenario" "Return" "Trades" "WinRate"
    "MaxDD" "Result";
  printf "%s\n" (String.make 78 '-')

let _format_result (s : scenario) (a : actual) checks =
  let all_ok = List.for_all checks ~f:(fun c -> c.ok) in
  let result_str =
    if all_ok then "PASS" else sprintf "FAIL (%s)" (_failure_message checks)
  in
  printf "%-28s %7.1f%% %7.0f %7.1f%% %7.1f%%   %s\n" s.name a.total_return_pct
    a.total_trades a.win_rate a.max_drawdown_pct result_str;
  all_ok

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

(* ------------------------------------------------------------------ *)
(* Running one scenario                                                *)
(* ------------------------------------------------------------------ *)

let _run_scenario ~output_root (s : scenario) =
  eprintf "\n>>> Running %s: %s (%s to %s)\n%!" s.name s.description
    (Date.to_string s.start_date)
    (Date.to_string s.end_date);
  let result =
    Backtest_runner_lib.run_backtest ~start_date:s.start_date
      ~end_date:s.end_date ~overrides:s.config_overrides ()
  in
  let scenario_dir = Filename.concat output_root s.name in
  Core_unix.mkdir_p scenario_dir;
  Backtest_runner_lib.write_output_dir ~output_dir:scenario_dir result;
  let a = _actual_of_result result in
  let checks = _run_checks a s.expected in
  (a, checks)

(* ------------------------------------------------------------------ *)
(* CLI                                                                 *)
(* ------------------------------------------------------------------ *)

let _usage () =
  eprintf "Usage: scenario_runner [--goldens | --smoke | --dir <path>]\n";
  Stdlib.exit 1

let _parse_args () =
  let argv = Sys.get_argv () in
  match Array.to_list argv with
  | _ :: "--goldens" :: _ -> _goldens_dir ()
  | _ :: "--smoke" :: _ -> _smoke_dir ()
  | _ :: "--dir" :: path :: _ -> path
  | [ _ ] -> _goldens_dir ()
  | _ -> _usage ()

let () =
  let dir = _parse_args () in
  let files = _list_scenario_files dir in
  if List.is_empty files then (
    eprintf "No .sexp scenario files found in %s\n" dir;
    Stdlib.exit 1);
  eprintf "Loading %d scenarios from %s\n%!" (List.length files) dir;
  let scenarios = List.map files ~f:_load_scenario in
  let output_root = _make_output_root () in
  eprintf "Output root: %s\n%!" output_root;
  _print_header ();
  let pass_flags =
    List.map scenarios ~f:(fun s ->
        let a, checks = _run_scenario ~output_root s in
        _format_result s a checks)
  in
  let all_pass = List.for_all pass_flags ~f:Fn.id in
  let n_pass = List.count pass_flags ~f:Fn.id in
  let n_total = List.length pass_flags in
  printf "\n%d/%d scenarios passed.\n" n_pass n_total;
  if not all_pass then Stdlib.exit 1
