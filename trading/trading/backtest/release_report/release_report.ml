open Core

(* Record types and their sexp converters live in [Release_report_types] so the
   on-disk loader ([Release_report_loader]) can build them without a circular
   dependency; re-exported here so the public API is unchanged. *)
include Release_report_types

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
let load_scenario_run = Release_report_loader.load_scenario_run

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

(* --- All-eligible + benchmark-relative sections ---

   Both sections are rendered by {!Release_report_comparisons}, extracted out
   of this file to keep it under the file-length limit (see
   [trading/devtools/checks/linter_exceptions.conf]). That module has no
   dependency on this one (same circular-dependency reason as
   {!Release_report_diagnostics} above), so we adapt our [scenario_run] pairs
   into its plain record shapes here. *)

let _to_all_eligible_fields (s : all_eligible_summary) :
    Release_report_comparisons.all_eligible_fields =
  {
    trade_count = s.trade_count;
    winners = s.winners;
    losers = s.losers;
    win_rate_pct = s.win_rate_pct;
    mean_return_pct = s.mean_return_pct;
    median_return_pct = s.median_return_pct;
    total_pnl_dollars = s.total_pnl_dollars;
    trades_csv_path = s.trades_csv_path;
  }

let _all_eligible_section paired =
  let pairs =
    List.map paired ~f:(fun (cur, prior) ->
        {
          Release_report_comparisons.ae_name = cur.name;
          ae_current = Option.map cur.all_eligible ~f:_to_all_eligible_fields;
          ae_prior = Option.map prior.all_eligible ~f:_to_all_eligible_fields;
        })
  in
  Release_report_comparisons.render_all_eligible pairs

let _to_benchmark_relative_fields (b : benchmark_relative_summary) :
    Release_report_comparisons.benchmark_relative_fields =
  {
    alpha_pct_annualized = b.alpha_pct_annualized;
    beta = b.beta;
    information_ratio = b.information_ratio;
    tracking_error_pct_annualized = b.tracking_error_pct_annualized;
    correlation = b.correlation;
  }

let _benchmark_relative_section paired =
  let pairs =
    List.map paired ~f:(fun (cur, prior) ->
        {
          Release_report_comparisons.br_name = cur.name;
          br_current =
            Option.map cur.benchmark_relative ~f:_to_benchmark_relative_fields;
          br_prior =
            Option.map prior.benchmark_relative ~f:_to_benchmark_relative_fields;
        })
  in
  Release_report_comparisons.render_benchmark_relative pairs

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
