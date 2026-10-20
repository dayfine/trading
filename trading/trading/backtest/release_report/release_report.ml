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
    Release_report_sections.header ~title:"Release perf report"
      ~current:t.current_label ~prior:t.prior_label
    @ Release_report_sections.trading t.paired
    @ _benchmark_relative_section t.paired
    @ _trade_quality_section t.paired
    @ _all_eligible_section t.paired
    @ _optimal_strategy_section t.paired
    @ Release_report_sections.rss ~threshold_pct:thresholds.threshold_rss_pct
        t.paired
    @ Release_report_sections.wall ~threshold_pct:thresholds.threshold_wall_pct
        t.paired
    @ _one_sided_section ~title:"Current-only scenarios" t.current_only
    @ _one_sided_section ~title:"Prior-only scenarios" t.prior_only
  in
  String.concat ~sep:"\n" lines ^ "\n"
