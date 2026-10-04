(* Actual-metrics record, range checks and result-row formatting for
   [scenario_runner]. Extracted from scenario_runner.ml (file_length cleanup). *)

open Core

(* Actual metrics extracted from a run — serialized so the parent process
   can read back each child's result. *)

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  open_positions_value : float; [@sexp.default Float.nan]
      (* Signed mark-to-market value of open positions at run end. Defaults to
         NaN on read so pre-rename actual.sexp files (which used the
         [unrealized_pnl] field for this same quantity) still parse. *)
  unrealized_pnl : float;
      (* Post-rename: true unrealized P&L (OpenPositionsValue - cost basis).
         Pre-rename actual.sexp files carry the legacy mtm-value here. *)
  sortino_ratio_annualized : float; [@sexp.default Float.nan]
      (* M5.2c Sortino — defaults to NaN on read so pre-pin actual.sexp files
         still parse. *)
  calmar_ratio : float; [@sexp.default Float.nan]
      (* M5.2c Calmar (CAGR / |MaxDD|) — defaults to NaN as above. *)
  ulcer_index : float; [@sexp.default Float.nan]
      (* M5.2c Ulcer Index — defaults to NaN as above. *)
  force_liquidations_count : int; [@sexp.default 0]
      (* G4 (force-liquidation policy). Defaults to 0 on read so pre-G4
         actual.sexp files that don't carry the field still parse. *)
  crashed : bool; [@sexp.default false]
      (* True when the backtest's [Backtest.Runner.run_backtest] raised an
         exception (e.g. an unhandled simulator-state invariant trip). The
         child writes a sentinel [actual.sexp] in that case so the parent
         row reports a meaningful FAIL with metrics filled with sentinel
         values rather than the silent "did not write actual.sexp" path.
         Defaults to [false] on read so pre-flag actual.sexp files that
         don't carry the field still parse. *)
  crash_message : string; [@sexp.default ""]
      (* Human-readable [Exn.to_string] of the exception that crashed the
         child, for diagnosis. Empty string when [crashed = false]. *)
}
[@@deriving sexp]

let actual_of_result (r : Backtest.Runner.result) =
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
    open_positions_value = get OpenPositionsValue;
    unrealized_pnl = get UnrealizedPnl;
    sortino_ratio_annualized = get SortinoRatioAnnualized;
    calmar_ratio = get CalmarRatio;
    ulcer_index = get UlcerIndex;
    force_liquidations_count = List.length r.force_liquidations;
    crashed = false;
    crash_message = "";
  }

(** Build a sentinel [actual] for a crashed run. Uses out-of-range numeric
    values (-100% return, 0 trades, very large drawdown) so the parent's range
    checks fail explicitly rather than passing on NaN. The [crashed] flag
    distinguishes a genuine "strategy lost almost everything" run from a true
    unhandled-exception abort. *)
let crashed_actual ~msg =
  {
    total_return_pct = -100.0;
    total_trades = 0.0;
    win_rate = 0.0;
    sharpe_ratio = 0.0;
    max_drawdown_pct = 100.0;
    avg_holding_days = 0.0;
    open_positions_value = 0.0;
    unrealized_pnl = 0.0;
    sortino_ratio_annualized = Float.nan;
    calmar_ratio = Float.nan;
    ulcer_index = Float.nan;
    force_liquidations_count = 0;
    crashed = true;
    crash_message = msg;
  }

(* Range checking *)

type check = { name : string; value : float; range : Scenario.range; ok : bool }

let _check_one name value (range : Scenario.range) =
  let ok = Scenario.in_range range value in
  { name; value; range; ok }

(** Read the canonical [wall_seconds.txt] perf-report file from [scenario_dir].
    Returns [NaN] when missing — same skip-the-check semantic as NaN handling in
    {!Scenario.in_range}. *)
let read_wall_seconds ~scenario_dir =
  let path = Filename.concat scenario_dir "wall_seconds.txt" in
  try Float.of_string (String.strip (In_channel.read_all path))
  with _ -> Float.nan

let run_checks ?(wall_seconds = Float.nan) (a : actual) (e : Scenario.expected)
    =
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
  let append_opt name value range_opt acc =
    match range_opt with
    | None -> acc
    | Some range -> acc @ [ _check_one name value range ]
  in
  base
  |> append_opt "open_positions_value" a.open_positions_value
       e.open_positions_value
  |> append_opt "unrealized_pnl" a.unrealized_pnl e.unrealized_pnl
  |> append_opt "sortino_ratio_annualized" a.sortino_ratio_annualized
       e.sortino_ratio_annualized
  |> append_opt "calmar_ratio" a.calmar_ratio e.calmar_ratio
  |> append_opt "ulcer_index" a.ulcer_index e.ulcer_index
  |> append_opt "wall_seconds" wall_seconds e.wall_seconds

let _failure_message checks =
  List.filter checks ~f:(fun c -> not c.ok)
  |> List.map ~f:(fun c ->
      if Float.(c.value < c.range.min_f) then
        sprintf "%s low (%.2f < %.2f)" c.name c.value c.range.min_f
      else sprintf "%s high (%.2f > %.2f)" c.name c.value c.range.max_f)
  |> String.concat ~sep:"; "

(* Output *)

let print_header () =
  printf "%-28s %8s %7s %8s %8s   %s\n" "Scenario" "Return" "Trades" "WinRate"
    "MaxDD" "Result";
  printf "%s\n" (String.make 78 '-')

let format_row (s : Scenario.t) (a : actual) checks =
  let all_ok = List.for_all checks ~f:(fun c -> c.ok) in
  let result_str =
    if a.crashed then sprintf "FAIL (scenario crashed: %s)" a.crash_message
    else if all_ok then "PASS"
    else sprintf "FAIL (%s)" (_failure_message checks)
  in
  printf "%-28s %7.1f%% %7.0f %7.1f%% %7.1f%%   %s\n" s.name a.total_return_pct
    a.total_trades a.win_rate a.max_drawdown_pct result_str;
  all_ok && not a.crashed

(* Parent-side: read back the child's actual.sexp and run checks *)

let load_actual ~output_root (s : Scenario.t) =
  try
    Some
      (actual_of_sexp (Sexp.load_sexp (Output_root.actual_path ~output_root s)))
  with _ -> None

let print_crashed_row (s : Scenario.t) =
  printf "%-28s %8s %7s %8s %8s   %s\n" s.name "-" "-" "-" "-"
    "FAIL (scenario crashed or did not write actual.sexp)"

let process_result ~output_root s =
  (* On both [Succeeded] and [Crashed] statuses, attempt to load the child's
     [actual.sexp] first. The child now writes a sentinel actual.sexp (with
     [crashed = true]) on the unhandled-exception path before exiting non-zero,
     so a [Crashed] status with a parseable actual.sexp is the new graceful-
     degradation path. The fallback [print_crashed_row] is kept for genuinely
     silent failures (e.g. SIGKILL, child exit before [_run_scenario_in_child]'s
     mkdir, or filesystem errors during the sentinel write). *)
  match load_actual ~output_root s with
  | Some a ->
      let scenario_dir = Output_root.scenario_dir ~output_root s in
      let wall_seconds = read_wall_seconds ~scenario_dir in
      let checks = run_checks ~wall_seconds a s.expected in
      format_row s a checks
  | None ->
      print_crashed_row s;
      false
