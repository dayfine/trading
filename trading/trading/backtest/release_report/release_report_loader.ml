open Core
open Release_report_types

(* --- File helpers --- *)

let _read_first_line path =
  try
    let ic = In_channel.create path in
    let line = In_channel.input_line ic in
    In_channel.close ic;
    Option.bind line ~f:(fun s ->
        let s = String.strip s in
        if String.is_empty s then None else Some s)
  with _ -> None

let _read_optional_int path =
  Option.bind (_read_first_line path) ~f:(fun s ->
      try Some (Int.of_string s) with _ -> None)

let _read_optional_float path =
  Option.bind (_read_first_line path) ~f:(fun s ->
      try Some (Float.of_string s) with _ -> None)

let _try_load_trade_quality ~dir : Trade_audit_report.t option =
  (* The audit-report loader requires [trades.csv]; [trade_audit.sexp] is
     optional. If [trades.csv] is missing we skip silently — the section
     simply renders as N/A in the comparison. Any malformed input is also
     swallowed: the audit is auxiliary, never a hard requirement. *)
  let trades_path = Filename.concat dir "trades.csv" in
  if not (Sys_unix.file_exists_exn trades_path) then None
  else try Some (Trade_audit_report.load ~scenario_dir:dir ()) with _ -> None

(* On-disk shape of [optimal_summary.sexp] — mirrors the
   [Optimal_strategy_runner.optimal_summary_artefact] producer. We re-declare
   the shape locally so [release_report] does not need to depend on the heavy
   [backtest_optimal] library; [@@sexp.allow_extra_fields] keeps us forward-
   compatible with future field additions on the producer side. *)
type _optimal_summary_artefact_on_disk = {
  constrained : optimal_summary;
  relaxed_macro : optimal_summary;
}
[@@deriving of_sexp] [@@sexp.allow_extra_fields]

let _try_load_optimal_summary ~dir ~scenario_name : optimal_summary_pair option
    =
  (* Both the structured sexp and the markdown report must exist for the
     section to be rendered — the link target would 404 otherwise. Any read /
     parse failure swallows silently: the optimal-strategy section is
     auxiliary, never a hard requirement. *)
  let sexp_path = Filename.concat dir "optimal_summary.sexp" in
  let md_path = Filename.concat dir "optimal_strategy.md" in
  if not (Sys_unix.file_exists_exn sexp_path && Sys_unix.file_exists_exn md_path)
  then None
  else
    try
      let artefact =
        _optimal_summary_artefact_on_disk_of_sexp (Sexp.load_sexp sexp_path)
      in
      let report_path = Filename.concat scenario_name "optimal_strategy.md" in
      Some
        {
          constrained = artefact.constrained;
          relaxed_macro = artefact.relaxed_macro;
          report_path;
        }
    with _ -> None

(* On-disk shape of [all_eligible/grade-C/summary.sexp] — mirrors the
   [Backtest_all_eligible.All_eligible.aggregate] producer. We re-declare the
   shape locally so [release_report] does not need to depend on the heavy
   [backtest_all_eligible] library; [@@sexp.allow_extra_fields] absorbs
   producer-side fields the comparison report does not surface (notably
   [return_buckets], which is a per-cell histogram and would inflate the report
   without per-batch context). The fields kept here are exactly those the
   rendered table reads. *)
type _all_eligible_summary_on_disk = {
  trade_count : int;
  winners : int;
  losers : int;
  win_rate_pct : float;
  mean_return_pct : float;
  median_return_pct : float;
  total_pnl_dollars : float;
}
[@@deriving of_sexp] [@@sexp.allow_extra_fields]

let _all_eligible_cell_subdir = Filename.concat "all_eligible" "grade-C"

let _try_load_all_eligible_summary ~dir ~scenario_name :
    all_eligible_summary option =
  (* Loads [<dir>/all_eligible/grade-C/summary.sexp] when present. The
     companion [trades.csv] path is recorded for the rendered drill-down link;
     the section still renders if the CSV is absent (the link will 404 but
     the metrics are intact). Any read / parse failure swallows silently —
     the all-eligible section is auxiliary, never a hard requirement. *)
  let cell_dir = Filename.concat dir _all_eligible_cell_subdir in
  let sexp_path = Filename.concat cell_dir "summary.sexp" in
  if not (Sys_unix.file_exists_exn sexp_path) then None
  else
    try
      let on_disk =
        _all_eligible_summary_on_disk_of_sexp (Sexp.load_sexp sexp_path)
      in
      let trades_csv_path =
        Filename.concat scenario_name
          (Filename.concat _all_eligible_cell_subdir "trades.csv")
      in
      Some
        {
          trade_count = on_disk.trade_count;
          winners = on_disk.winners;
          losers = on_disk.losers;
          win_rate_pct = on_disk.win_rate_pct;
          mean_return_pct = on_disk.mean_return_pct;
          median_return_pct = on_disk.median_return_pct;
          total_pnl_dollars = on_disk.total_pnl_dollars;
          trades_csv_path;
        }
    with _ -> None

(* On-disk metric labels for the five PR #1021 benchmark-relative metrics.
   [Metric_type.show] derives [Metric_types.Metric_type.t.<Variant>], which
   [metric_set_to_sexp_pairs] then [String.lowercase]s — yielding e.g.
   [metric_types.metric_type.t.benchmarkbeta]. We match by suffix (last
   dot-separated segment) so the loader survives if the producer's module path
   ever changes. *)
let _benchmark_relative_labels =
  [
    "benchmarkalphapctannualized";
    "benchmarkbeta";
    "informationratio";
    "trackingerrorpctannualized";
    "correlationtobenchmark";
  ]

let _metric_key_suffix label =
  match String.rsplit2 label ~on:'.' with
  | Some (_, suffix) -> suffix
  | None -> label

(* Extract the metric key/value alist from a [summary.sexp] sexp. The on-disk
   shape is [((... fields ...) (metrics ((<label> <value>) ...)))]; we walk the
   top-level list looking for [(metrics ...)]. Any malformed entry yields an
   empty alist — the report renders the benchmark-relative section as [None]
   in that case, which is the same graceful-skip path as a legacy summary. *)
let _metrics_alist_of_summary_sexp sexp =
  match sexp with
  | Sexp.List fields ->
      let rec find = function
        | [] -> []
        | Sexp.List [ Sexp.Atom "metrics"; Sexp.List pairs ] :: _ ->
            List.filter_map pairs ~f:(function
              | Sexp.List [ Sexp.Atom k; Sexp.Atom v ] -> (
                  try Some (_metric_key_suffix k, Float.of_string v)
                  with _ -> None)
              | _ -> None)
        | _ :: rest -> find rest
      in
      find fields
  | _ -> []

let _try_load_benchmark_relative ~summary_sexp :
    benchmark_relative_summary option =
  (* Build the suffix-keyed map once, then require all five labels. Missing
     any single label yields [None] — the report renders the section only
     when at least one side of a pair has [Some _], so this is the legacy-
     summary graceful-skip path. *)
  let alist = _metrics_alist_of_summary_sexp summary_sexp in
  let has_all =
    List.for_all _benchmark_relative_labels ~f:(fun lbl ->
        List.Assoc.mem alist lbl ~equal:String.equal)
  in
  if not has_all then None
  else
    let get lbl = List.Assoc.find_exn alist lbl ~equal:String.equal in
    Some
      {
        alpha_pct_annualized = get "benchmarkalphapctannualized";
        beta = get "benchmarkbeta";
        information_ratio = get "informationratio";
        tracking_error_pct_annualized = get "trackingerrorpctannualized";
        correlation = get "correlationtobenchmark";
      }

let load_scenario_run ~dir =
  let name = Filename.basename dir in
  let actual_path = Filename.concat dir "actual.sexp" in
  let summary_path = Filename.concat dir "summary.sexp" in
  if not (Sys_unix.file_exists_exn actual_path) then
    failwithf "Missing actual.sexp in %s" dir ();
  if not (Sys_unix.file_exists_exn summary_path) then
    failwithf "Missing summary.sexp in %s" dir ();
  let actual = actual_of_sexp (Sexp.load_sexp actual_path) in
  let summary_sexp = Sexp.load_sexp summary_path in
  let summary = summary_meta_of_sexp summary_sexp in
  let peak_rss_kb =
    _read_optional_int (Filename.concat dir "peak_rss_kb.txt")
  in
  let wall_seconds =
    _read_optional_float (Filename.concat dir "wall_seconds.txt")
  in
  let trade_quality = _try_load_trade_quality ~dir in
  let optimal_strategy = _try_load_optimal_summary ~dir ~scenario_name:name in
  let all_eligible = _try_load_all_eligible_summary ~dir ~scenario_name:name in
  let benchmark_relative = _try_load_benchmark_relative ~summary_sexp in
  {
    name;
    actual;
    summary;
    peak_rss_kb;
    wall_seconds;
    trade_quality;
    optimal_strategy;
    all_eligible;
    benchmark_relative;
  }
