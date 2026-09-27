open Core

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  open_positions_value : float option; [@sexp.option]
      (** Post-rename signed mark-to-market value of open positions. Optional
          for backward compat with actual.sexp files written before the rename
          (those carry the same value under [unrealized_pnl] instead). *)
  unrealized_pnl : float option; [@sexp.option]
      (** Post-rename: true unrealized P&L (OpenPositionsValue - cost basis).
          Pre-rename actual.sexp files carry the legacy mtm-value here. *)
  force_liquidations_count : int; [@sexp.default 0]
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type summary_meta = {
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  n_steps : int;
  initial_cash : float;
  final_portfolio_value : float;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type optimal_summary = {
  total_round_trips : int;
  winners : int;
  losers : int;
  total_return_pct : float;
  win_rate_pct : float;
  avg_r_multiple : float;
  profit_factor : float;
  max_drawdown_pct : float;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type optimal_summary_pair = {
  constrained : optimal_summary;
  relaxed_macro : optimal_summary;
  report_path : string;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type all_eligible_summary = {
  trade_count : int;
  winners : int;
  losers : int;
  win_rate_pct : float;
  mean_return_pct : float;
  median_return_pct : float;
  total_pnl_dollars : float;
  trades_csv_path : string;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type benchmark_relative_summary = {
  alpha_pct_annualized : float;
  beta : float;
  information_ratio : float;
  tracking_error_pct_annualized : float;
  correlation : float;
}
[@@deriving sexp]

type scenario_run = {
  name : string;
  actual : actual;
  summary : summary_meta;
  peak_rss_kb : int option;
  wall_seconds : float option;
  trade_quality : Trade_audit_report.t option;
  optimal_strategy : optimal_summary_pair option;
  all_eligible : all_eligible_summary option;
  benchmark_relative : benchmark_relative_summary option;
}
[@@deriving sexp]

type t = {
  current_label : string;
  prior_label : string;
  paired : (scenario_run * scenario_run) list;
  current_only : string list;
  prior_only : string list;
}
[@@deriving sexp]

type thresholds = { threshold_rss_pct : float; threshold_wall_pct : float }
[@@deriving sexp]

let default_thresholds = { threshold_rss_pct = 10.0; threshold_wall_pct = 25.0 }

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

let _list_scenario_subdirs root =
  if not (Sys_unix.is_directory_exn root) then
    failwithf "Batch dir is not a directory: %s" root ();
  Sys_unix.ls_dir root
  |> List.sort ~compare:String.compare
  |> List.filter_map ~f:(fun entry ->
      let path = Filename.concat root entry in
      if
        Sys_unix.is_directory_exn path
        && Sys_unix.file_exists_exn (Filename.concat path "actual.sexp")
      then Some entry
      else None)

let _label_of_dir dir =
  match Filename.basename dir with "" -> dir | name -> name

let _pair_scenarios ~current_runs ~prior_runs =
  let by_name runs =
    List.map runs ~f:(fun (r : scenario_run) -> (r.name, r))
    |> Map.of_alist_exn (module String)
  in
  let current_map = by_name current_runs in
  let prior_map = by_name prior_runs in
  let names_current = Map.key_set current_map in
  let names_prior = Map.key_set prior_map in
  let common = Set.inter names_current names_prior |> Set.to_list in
  let only_current = Set.diff names_current names_prior |> Set.to_list in
  let only_prior = Set.diff names_prior names_current |> Set.to_list in
  let paired =
    List.map common ~f:(fun name ->
        (Map.find_exn current_map name, Map.find_exn prior_map name))
  in
  (paired, only_current, only_prior)

let load ~current ~prior =
  let load_batch root =
    let subdirs = _list_scenario_subdirs root in
    List.map subdirs ~f:(fun name ->
        load_scenario_run ~dir:(Filename.concat root name))
  in
  let current_runs = load_batch current in
  let prior_runs = load_batch prior in
  let paired, current_only, prior_only =
    _pair_scenarios ~current_runs ~prior_runs
  in
  {
    current_label = _label_of_dir current;
    prior_label = _label_of_dir prior;
    paired;
    current_only;
    prior_only;
  }

(* --- Rendering helpers --- *)

let _delta_pct ~current ~prior =
  if Float.equal prior 0.0 then None
  else Some ((current -. prior) /. prior *. 100.0)

let _fmt_delta_pct = function None -> "n/a" | Some d -> sprintf "%+.1f%%" d
let _fmt_float_2 v = sprintf "%.2f" v
let _fmt_float_1 v = sprintf "%.1f" v
let _fmt_int_opt = function Some i -> Int.to_string i | None -> "n/a"
let _fmt_float_opt_1 = function Some f -> sprintf "%.1f" f | None -> "n/a"

let _delta_int_pct ~current ~prior =
  match (current, prior) with
  | Some c, Some p ->
      _delta_pct ~current:(Float.of_int c) ~prior:(Float.of_int p)
  | _ -> None

let _delta_float_pct ~current ~prior =
  match (current, prior) with
  | Some c, Some p -> _delta_pct ~current:c ~prior:p
  | _ -> None

(* --- Section renderers ---

   Each renderer returns a list of lines (no trailing newline). The top-level
   [render] joins everything with "\n" and adds a final newline. *)

let _section_header ~title ~current ~prior =
  [
    sprintf "# %s" title;
    "";
    sprintf "- Current: `%s`" current;
    sprintf "- Prior:   `%s`" prior;
    "";
  ]

let _flag ~delta_pct ~threshold =
  match delta_pct with
  | Some d when Float.(d > threshold) -> " :rotating_light:"
  | _ -> ""

let _row_trading_metrics (cur, prior) =
  let row label fmt get =
    sprintf "| %s | %s | %s | %s |" label
      (fmt (get cur.actual))
      (fmt (get prior.actual))
      (_fmt_delta_pct
         (_delta_pct ~current:(get cur.actual) ~prior:(get prior.actual)))
  in
  let force_liq_flag a =
    if a.force_liquidations_count > 0 then " :rotating_light:" else ""
  in
  [
    sprintf "### %s" cur.name;
    "";
    sprintf "Period: %s → %s · Universe: %d · Steps: %d"
      (Date.to_string cur.summary.start_date)
      (Date.to_string cur.summary.end_date)
      cur.summary.universe_size cur.summary.n_steps;
    "";
    "| Metric | Current | Prior | Δ% |";
    "|---|---:|---:|---:|";
    row "Return %" _fmt_float_2 (fun a -> a.total_return_pct);
    row "Sharpe" _fmt_float_2 (fun a -> a.sharpe_ratio);
    row "Win rate %" _fmt_float_1 (fun a -> a.win_rate);
    row "Max DD %" _fmt_float_2 (fun a -> a.max_drawdown_pct);
    row "Trades" _fmt_float_1 (fun a -> a.total_trades);
    row "Avg hold (d)" _fmt_float_2 (fun a -> a.avg_holding_days);
    (* G4 force-liquidation count. Non-zero on either side flags a primary
       stop-machinery regression (red light glyph). *)
    sprintf "| Force-liq count | %d%s | %d%s | %s |"
      cur.actual.force_liquidations_count
      (force_liq_flag cur.actual)
      prior.actual.force_liquidations_count
      (force_liq_flag prior.actual)
      (_fmt_delta_pct
         (_delta_pct
            ~current:(Float.of_int cur.actual.force_liquidations_count)
            ~prior:(Float.of_int prior.actual.force_liquidations_count)));
    "";
  ]

let _trading_section paired =
  if List.is_empty paired then
    [ "## Trading metrics"; ""; "_No paired scenarios._"; "" ]
  else
    let header = [ "## Trading metrics"; "" ] in
    let body = List.concat_map paired ~f:_row_trading_metrics in
    header @ body

let _row_rss ~thresholds (cur, prior) =
  let cur_rss = cur.peak_rss_kb in
  let prior_rss = prior.peak_rss_kb in
  let delta = _delta_int_pct ~current:cur_rss ~prior:prior_rss in
  let flag = _flag ~delta_pct:delta ~threshold:thresholds.threshold_rss_pct in
  sprintf "| %s | %s | %s | %s%s |" cur.name (_fmt_int_opt cur_rss)
    (_fmt_int_opt prior_rss) (_fmt_delta_pct delta) flag

let _rss_section ~thresholds paired =
  let header =
    [
      "## Peak RSS (kB)";
      "";
      sprintf "Regression flag: Δ%% > %.0f%%" thresholds.threshold_rss_pct;
      "";
      "| Scenario | Current | Prior | Δ% |";
      "|---|---:|---:|---:|";
    ]
  in
  let body = List.map paired ~f:(_row_rss ~thresholds) in
  let footer = [ "" ] in
  header @ body @ footer

let _row_wall ~thresholds (cur, prior) =
  let cur_wall = cur.wall_seconds in
  let prior_wall = prior.wall_seconds in
  let delta = _delta_float_pct ~current:cur_wall ~prior:prior_wall in
  let flag = _flag ~delta_pct:delta ~threshold:thresholds.threshold_wall_pct in
  sprintf "| %s | %s | %s | %s%s |" cur.name
    (_fmt_float_opt_1 cur_wall)
    (_fmt_float_opt_1 prior_wall)
    (_fmt_delta_pct delta) flag

let _wall_section ~thresholds paired =
  let header =
    [
      "## Wall time (s)";
      "";
      sprintf "Regression flag: Δ%% > %.0f%%" thresholds.threshold_wall_pct;
      "";
      "| Scenario | Current | Prior | Δ% |";
      "|---|---:|---:|---:|";
    ]
  in
  let body = List.map paired ~f:(_row_wall ~thresholds) in
  let footer = [ "" ] in
  header @ body @ footer

let _one_sided_section ~title names =
  if List.is_empty names then []
  else
    let header = [ sprintf "## %s" title; "" ] in
    let body = List.map names ~f:(fun n -> sprintf "- `%s`" n) in
    header @ body @ [ "" ]

(* --- Trade quality summary + Optimal-strategy counterfactual delta ---

   Both sections are rendered by {!Release_report_diagnostics}, extracted out
   of this file to keep it under the file-length limit (see
   [trading/devtools/checks/linter_exceptions.conf]). That module has no
   dependency on this one (to avoid a circular module dependency within the
   [release_report] library, since this file is what calls into it), so we
   adapt our [scenario_run] pairs into its plain record shapes here. *)

let _trade_quality_section paired =
  let pairs =
    List.map paired ~f:(fun (cur, prior) ->
        {
          Release_report_diagnostics.name = cur.name;
          current = cur.trade_quality;
          prior = prior.trade_quality;
        })
  in
  Release_report_diagnostics.render_trade_quality pairs

(* The runner's [Optimal_types.optimal_summary.total_return_pct] is a fraction
   (e.g. 0.30 = +30%); the actual side's [actual.total_return_pct] is already a
   percentage (e.g. 30.0). Normalise both to percentage units so the headline
   rows are directly comparable. *)
let _opt_return_pct_pp (s : optimal_summary) = s.total_return_pct *. 100.0
let _fmt_optional_str = function Some s -> s | None -> "—"

let _to_optimal_side (run : scenario_run) :
    Release_report_diagnostics.optimal_side =
  {
    actual_total_return_pct = run.actual.total_return_pct;
    optimal =
      Option.map run.optimal_strategy ~f:(fun pair ->
          {
            Release_report_diagnostics.constrained_pct =
              _opt_return_pct_pp pair.constrained;
            relaxed_pct = _opt_return_pct_pp pair.relaxed_macro;
          });
    report_link =
      Option.map run.optimal_strategy ~f:(fun pair -> pair.report_path);
  }

let _optimal_strategy_section paired =
  let pairs =
    List.map paired ~f:(fun (cur, prior) ->
        {
          Release_report_diagnostics.opt_name = cur.name;
          opt_current = _to_optimal_side cur;
          opt_prior = _to_optimal_side prior;
        })
  in
  Release_report_diagnostics.render_optimal_strategy pairs

(* --- All-eligible diagnostic section ---

   For each paired scenario where at least one side has [Some _] all-eligible
   artefacts, surface the headline aggregate (trade count, win rate, mean /
   median return, total P&L) for current vs prior side. The diagnostic
   measures opportunity cost: it sizes every cascade-admissible Stage-2
   breakout signal at a uniform fixed-dollar entry, bypassing every
   portfolio-level rejection (cash, exposure cap, sector concentration), and
   reports what each signal would have returned. A negative win rate / total
   P&L across the universe with a positive [actual] return implies the
   cascade is correctly keeping the average signal out; the inverse implies
   the cascade is leaving alpha on the table. Per-trade drill-down lives in
   the linked [trades.csv]. *)

let _fmt_pct_fraction_signed v = sprintf "%+.2f%%" (v *. 100.0)
let _fmt_pnl_dollars v = sprintf "%+.0f" v
let _fmt_int_signed v = sprintf "%d" v

let _alleli_row ~label ~cur_str ~prior_str =
  sprintf "| %s | %s | %s |" label cur_str prior_str

let _alleli_field_str (run : scenario_run) ~(fmt : float -> string)
    ~(get : all_eligible_summary -> float) =
  match run.all_eligible with None -> "—" | Some s -> fmt (get s)

let _alleli_int_field_str (run : scenario_run)
    ~(get : all_eligible_summary -> int) =
  match run.all_eligible with None -> "—" | Some s -> _fmt_int_signed (get s)

let _alleli_link_str (run : scenario_run) =
  Option.map run.all_eligible ~f:(fun s ->
      sprintf "[trades.csv](%s)" s.trades_csv_path)
  |> _fmt_optional_str

let _row_all_eligible_for_pair (cur, prior) =
  [
    sprintf "### %s" cur.name;
    "";
    sprintf "Drill-down — Current: %s · Prior: %s" (_alleli_link_str cur)
      (_alleli_link_str prior);
    "";
    "| Metric | Current | Prior |";
    "|---|---:|---:|";
    _alleli_row ~label:"Trades"
      ~cur_str:(_alleli_int_field_str cur ~get:(fun s -> s.trade_count))
      ~prior_str:(_alleli_int_field_str prior ~get:(fun s -> s.trade_count));
    _alleli_row ~label:"Winners"
      ~cur_str:(_alleli_int_field_str cur ~get:(fun s -> s.winners))
      ~prior_str:(_alleli_int_field_str prior ~get:(fun s -> s.winners));
    _alleli_row ~label:"Losers"
      ~cur_str:(_alleli_int_field_str cur ~get:(fun s -> s.losers))
      ~prior_str:(_alleli_int_field_str prior ~get:(fun s -> s.losers));
    _alleli_row ~label:"Win rate"
      ~cur_str:
        (_alleli_field_str cur ~fmt:_fmt_pct_fraction_signed ~get:(fun s ->
             s.win_rate_pct))
      ~prior_str:
        (_alleli_field_str prior ~fmt:_fmt_pct_fraction_signed ~get:(fun s ->
             s.win_rate_pct));
    _alleli_row ~label:"Mean return"
      ~cur_str:
        (_alleli_field_str cur ~fmt:_fmt_pct_fraction_signed ~get:(fun s ->
             s.mean_return_pct))
      ~prior_str:
        (_alleli_field_str prior ~fmt:_fmt_pct_fraction_signed ~get:(fun s ->
             s.mean_return_pct));
    _alleli_row ~label:"Median return"
      ~cur_str:
        (_alleli_field_str cur ~fmt:_fmt_pct_fraction_signed ~get:(fun s ->
             s.median_return_pct))
      ~prior_str:
        (_alleli_field_str prior ~fmt:_fmt_pct_fraction_signed ~get:(fun s ->
             s.median_return_pct));
    _alleli_row ~label:"Total P&L ($)"
      ~cur_str:
        (_alleli_field_str cur ~fmt:_fmt_pnl_dollars ~get:(fun s ->
             s.total_pnl_dollars))
      ~prior_str:
        (_alleli_field_str prior ~fmt:_fmt_pnl_dollars ~get:(fun s ->
             s.total_pnl_dollars));
    "";
  ]

let _all_eligible_section paired =
  let with_alleli =
    List.filter paired ~f:(fun (c, p) ->
        Option.is_some c.all_eligible || Option.is_some p.all_eligible)
  in
  if List.is_empty with_alleli then []
  else
    let header =
      [
        "## All-eligible diagnostic";
        "";
        "Fixed-dollar opportunity-cost diagnostic — every cascade-admissible \
         Stage-2 breakout signal is sized at a uniform entry and tracked to \
         its natural exit, bypassing portfolio-level rejections \
         (`all_eligible/grade-C/summary.sexp` required). Compare against \
         actual trading metrics: negative aggregate P&L with a positive actual \
         return means the cascade is correctly keeping the average signal out; \
         the inverse means signal alpha is being left on the table. Per-trade \
         drill-down lives in the linked `trades.csv`.";
        "";
      ]
    in
    let body = List.concat_map with_alleli ~f:_row_all_eligible_for_pair in
    header @ body

(* --- Benchmark-relative section ---

   For each paired scenario where at least one side has [Some _]
   benchmark-relative artefacts (i.e. all five PR #1021 metrics were emitted in
   [summary.sexp]'s metrics block), surface α, β, IR, TE, and Pearson
   correlation side-by-side. The five metrics together pin how much of the
   strategy's return is benchmark-explained vs. residual: a strategy with
   β ≈ 1, corr ≈ 1, α ≈ 0 is replicating the benchmark; β < 1 with positive
   α and low correlation indicates a genuinely independent return stream.

   Δ is rendered as (current - prior) in absolute units for β, IR, and corr
   (which are unitless ratios) and in percentage points (pp) for α and TE
   (which are already in %/yr). Rendered only when at least one side has
   [Some _]; missing sides print "—". *)

let _br_field_str (run : scenario_run) ~(fmt : float -> string)
    ~(get : benchmark_relative_summary -> float) =
  match run.benchmark_relative with None -> "—" | Some b -> fmt (get b)

let _br_delta_str ~(fmt : float -> string)
    ~(get : benchmark_relative_summary -> float) cur prior =
  match (cur.benchmark_relative, prior.benchmark_relative) with
  | Some c, Some p -> fmt (get c -. get p)
  | _ -> "—"

let _fmt_signed_3 v = sprintf "%+.3f" v
let _fmt_signed_pp_2 v = sprintf "%+.2f pp" v
let _fmt_signed_pct_2 v = sprintf "%+.2f%%" v

let _br_row ~label ~cur_str ~prior_str ~delta_str =
  sprintf "| %s | %s | %s | %s |" label cur_str prior_str delta_str

let _br_value_row (cur, prior) ~label ~fmt_val ~fmt_delta ~get =
  _br_row ~label
    ~cur_str:(_br_field_str cur ~fmt:fmt_val ~get)
    ~prior_str:(_br_field_str prior ~fmt:fmt_val ~get)
    ~delta_str:(_br_delta_str ~fmt:fmt_delta ~get cur prior)

let _row_benchmark_relative_for_pair (cur, prior) =
  [
    sprintf "### %s" cur.name;
    "";
    "| Metric | Current | Prior | \xce\x94 |";
    "|---|---:|---:|---:|";
    _br_value_row (cur, prior) ~label:"Alpha (%/yr)" ~fmt_val:_fmt_signed_pct_2
      ~fmt_delta:_fmt_signed_pp_2 ~get:(fun b -> b.alpha_pct_annualized);
    _br_value_row (cur, prior) ~label:"Beta" ~fmt_val:_fmt_signed_3
      ~fmt_delta:_fmt_signed_3 ~get:(fun b -> b.beta);
    _br_value_row (cur, prior) ~label:"Information ratio" ~fmt_val:_fmt_signed_3
      ~fmt_delta:_fmt_signed_3 ~get:(fun b -> b.information_ratio);
    _br_value_row (cur, prior) ~label:"Tracking error (%/yr)"
      ~fmt_val:_fmt_signed_pct_2 ~fmt_delta:_fmt_signed_pp_2 ~get:(fun b ->
        b.tracking_error_pct_annualized);
    _br_value_row (cur, prior) ~label:"Correlation" ~fmt_val:_fmt_signed_3
      ~fmt_delta:_fmt_signed_3 ~get:(fun b -> b.correlation);
    "";
  ]

let _benchmark_relative_section paired =
  let with_br =
    List.filter paired ~f:(fun (c, p) ->
        Option.is_some c.benchmark_relative
        || Option.is_some p.benchmark_relative)
  in
  if List.is_empty with_br then []
  else
    let header =
      [
        "## Benchmark-relative";
        "";
        "CAPM-style residual-return diagnostics from PR #1021: α (annualised \
         intercept of [r_strat = α + β · r_bench]), β (slope), Information \
         Ratio (α / TE), Tracking Error (annualised stdev of the active-return \
         series), and Pearson correlation. Δ is current minus prior — α / TE \
         in percentage points, β / IR / correlation in absolute units. \
         Rendered only for scenarios whose [summary.sexp] metrics block \
         carries all five labels.";
        "";
      ]
    in
    let body = List.concat_map with_br ~f:_row_benchmark_relative_for_pair in
    header @ body

let render ?(thresholds = default_thresholds) (t : t) =
  let lines =
    _section_header ~title:"Release perf report" ~current:t.current_label
      ~prior:t.prior_label
    @ _trading_section t.paired
    @ _benchmark_relative_section t.paired
    @ _trade_quality_section t.paired
    @ _all_eligible_section t.paired
    @ _optimal_strategy_section t.paired
    @ _rss_section ~thresholds t.paired
    @ _wall_section ~thresholds t.paired
    @ _one_sided_section ~title:"Current-only scenarios" t.current_only
    @ _one_sided_section ~title:"Prior-only scenarios" t.prior_only
  in
  String.concat ~sep:"\n" lines ^ "\n"
