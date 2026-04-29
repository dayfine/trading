open Core

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  unrealized_pnl : float option; [@sexp.option]
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

type scenario_run = {
  name : string;
  actual : actual;
  summary : summary_meta;
  peak_rss_kb : int option;
  wall_seconds : float option;
  trade_quality : Trade_audit_report.t option;
  optimal_strategy : optimal_summary_pair option;
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
  else try Some (Trade_audit_report.load ~scenario_dir:dir) with _ -> None

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

let load_scenario_run ~dir =
  let name = Filename.basename dir in
  let actual_path = Filename.concat dir "actual.sexp" in
  let summary_path = Filename.concat dir "summary.sexp" in
  if not (Sys_unix.file_exists_exn actual_path) then
    failwithf "Missing actual.sexp in %s" dir ();
  if not (Sys_unix.file_exists_exn summary_path) then
    failwithf "Missing summary.sexp in %s" dir ();
  let actual = actual_of_sexp (Sexp.load_sexp actual_path) in
  let summary = summary_meta_of_sexp (Sexp.load_sexp summary_path) in
  let peak_rss_kb =
    _read_optional_int (Filename.concat dir "peak_rss_kb.txt")
  in
  let wall_seconds =
    _read_optional_float (Filename.concat dir "wall_seconds.txt")
  in
  let trade_quality = _try_load_trade_quality ~dir in
  let optimal_strategy = _try_load_optimal_summary ~dir ~scenario_name:name in
  {
    name;
    actual;
    summary;
    peak_rss_kb;
    wall_seconds;
    trade_quality;
    optimal_strategy;
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

(* --- Trade quality summary ---

   For each paired scenario where at least one side has a [trade_quality]
   record, surface the headline behavioural / Weinstein-conformance numbers
   and the per-side delta. This complements the trading-metrics table: a
   scenario can show flat returns while its trade quality regresses (e.g.
   higher exit-losers-too-late or a falling Weinstein spirit score). *)

type _quality_summary = {
  spirit_score : float option;
      (* avg per-trade Weinstein score [[0,1]]; None when no analysis *)
  mean_r_multiple : float option;
  median_r_multiple : float option;
  trades_per_year : float option;
  over_trading_flag : bool;
  exit_winners_flagged : int;
  winners_evaluated : int;
  exit_losers_flagged : int;
  losers_evaluated : int;
  decision_quality_win_rate_pct : float;
}

let _finite_or_none v = if Float.is_finite v then Some v else None

let _r_multiple_stats
    (ratings : Trade_audit_report.Trade_audit_ratings.rating list) =
  let rs =
    List.filter_map ratings ~f:(fun r ->
        if Float.is_finite r.Trade_audit_report.Trade_audit_ratings.r_multiple
        then Some r.r_multiple
        else None)
  in
  if List.is_empty rs then (None, None)
  else
    let sorted = List.sort rs ~compare:Float.compare in
    let n = List.length sorted in
    let mean = List.fold sorted ~init:0.0 ~f:( +. ) /. Float.of_int n in
    let median =
      if n mod 2 = 1 then List.nth_exn sorted (n / 2)
      else
        let a = List.nth_exn sorted ((n / 2) - 1) in
        let b = List.nth_exn sorted (n / 2) in
        (a +. b) /. 2.0
    in
    (Some mean, Some median)

let _summarize_quality (q : Trade_audit_report.t option) : _quality_summary =
  let empty =
    {
      spirit_score = None;
      mean_r_multiple = None;
      median_r_multiple = None;
      trades_per_year = None;
      over_trading_flag = false;
      exit_winners_flagged = 0;
      winners_evaluated = 0;
      exit_losers_flagged = 0;
      losers_evaluated = 0;
      decision_quality_win_rate_pct = 0.0;
    }
  in
  match q with
  | None -> empty
  | Some t -> (
      match t.analysis with
      | None -> empty
      | Some a ->
          let mean, median = _r_multiple_stats a.ratings in
          {
            spirit_score = _finite_or_none a.weinstein.spirit_score;
            mean_r_multiple = mean;
            median_r_multiple = median;
            trades_per_year =
              _finite_or_none a.behavioral.over_trading.trades_per_year;
            over_trading_flag = a.behavioral.over_trading.exceeds_threshold;
            exit_winners_flagged =
              a.behavioral.exit_winners_too_early.flagged_count;
            winners_evaluated =
              a.behavioral.exit_winners_too_early.winners_evaluated;
            exit_losers_flagged =
              a.behavioral.exit_losers_too_late.flagged_count;
            losers_evaluated =
              a.behavioral.exit_losers_too_late.losers_evaluated;
            decision_quality_win_rate_pct =
              a.decision_quality.overall_win_rate_pct;
          })

let _fmt_opt_float fmt = function Some v -> sprintf fmt v | None -> "n/a"
let _fmt_opt_score = _fmt_opt_float "%.3f"
let _fmt_opt_r = _fmt_opt_float "%+.2f"
let _fmt_opt_tpy = _fmt_opt_float "%.1f"
let _fmt_count_of n_total n_eval = sprintf "%d / %d" n_total n_eval

let _delta_opt_float ~current ~prior =
  match (current, prior) with Some c, Some p -> Some (c -. p) | _ -> None

let _fmt_delta_signed = function None -> "n/a" | Some d -> sprintf "%+.3f" d

let _row_quality_metric ~label ~current_str ~prior_str ~delta_str =
  sprintf "| %s | %s | %s | %s |" label current_str prior_str delta_str

let _fmt_delta_float_opt = function
  | None -> "n/a"
  | Some d -> sprintf "%+.1f" d

let _over_trading_str (s : _quality_summary) =
  sprintf "%s%s"
    (_fmt_opt_tpy s.trades_per_year)
    (if s.over_trading_flag then " :rotating_light:" else "")

let _score_rows ~(cur : _quality_summary) ~(prior : _quality_summary) =
  (* Float metrics with optional values: spirit score, R-multiple stats. *)
  let delta name f fmt =
    _row_quality_metric ~label:name
      ~current_str:(fmt (f cur))
      ~prior_str:(fmt (f prior))
      ~delta_str:
        (_fmt_delta_signed (_delta_opt_float ~current:(f cur) ~prior:(f prior)))
  in
  [
    delta "Weinstein spirit score" (fun s -> s.spirit_score) _fmt_opt_score;
    delta "Mean R-multiple" (fun s -> s.mean_r_multiple) _fmt_opt_r;
    delta "Median R-multiple" (fun s -> s.median_r_multiple) _fmt_opt_r;
  ]

let _count_rows ~(cur : _quality_summary) ~(prior : _quality_summary) =
  (* Integer counts + win rate — deltas are always-defined arithmetic. *)
  let delta_tpy =
    _delta_opt_float ~current:cur.trades_per_year ~prior:prior.trades_per_year
  in
  [
    _row_quality_metric ~label:"Trades / year"
      ~current_str:(_over_trading_str cur) ~prior_str:(_over_trading_str prior)
      ~delta_str:(_fmt_delta_float_opt delta_tpy);
    _row_quality_metric ~label:"Exit winners too early (flagged / evaluated)"
      ~current_str:
        (_fmt_count_of cur.exit_winners_flagged cur.winners_evaluated)
      ~prior_str:
        (_fmt_count_of prior.exit_winners_flagged prior.winners_evaluated)
      ~delta_str:
        (sprintf "%+d" (cur.exit_winners_flagged - prior.exit_winners_flagged));
    _row_quality_metric ~label:"Exit losers too late (flagged / evaluated)"
      ~current_str:(_fmt_count_of cur.exit_losers_flagged cur.losers_evaluated)
      ~prior_str:
        (_fmt_count_of prior.exit_losers_flagged prior.losers_evaluated)
      ~delta_str:
        (sprintf "%+d" (cur.exit_losers_flagged - prior.exit_losers_flagged));
    _row_quality_metric ~label:"Decision-quality win rate %"
      ~current_str:(sprintf "%.1f" cur.decision_quality_win_rate_pct)
      ~prior_str:(sprintf "%.1f" prior.decision_quality_win_rate_pct)
      ~delta_str:
        (sprintf "%+.1f"
           (cur.decision_quality_win_rate_pct
          -. prior.decision_quality_win_rate_pct));
  ]

let _quality_rows ~(cur : _quality_summary) ~(prior : _quality_summary) =
  _score_rows ~cur ~prior @ _count_rows ~cur ~prior

let _row_quality_for_pair (cur, prior) =
  let cur_q = _summarize_quality cur.trade_quality in
  let prior_q = _summarize_quality prior.trade_quality in
  [
    sprintf "### %s" cur.name;
    "";
    "| Metric | Current | Prior | Δ |";
    "|---|---:|---:|---:|";
  ]
  @ _quality_rows ~cur:cur_q ~prior:prior_q
  @ [ "" ]

let _trade_quality_section paired =
  let with_quality =
    List.filter paired ~f:(fun (c, p) ->
        Option.is_some c.trade_quality || Option.is_some p.trade_quality)
  in
  if List.is_empty with_quality then []
  else
    let header =
      [
        "## Trade quality";
        "";
        "Behavioural metrics + Weinstein conformance per scenario \
         (`trade_audit.sexp` required). Δ is current minus prior — lower \
         exit-winners-flagged / exit-losers-flagged is better; higher spirit \
         score and mean R-multiple is better.";
        "";
      ]
    in
    let body = List.concat_map with_quality ~f:_row_quality_for_pair in
    header @ body

(* --- Optimal-strategy counterfactual delta section ---

   For each paired scenario where at least one side has [Some _] optimal-
   strategy artefacts, surface the constrained + relaxed-macro counterfactual
   total returns alongside the actual total return, plus a per-side Δ from
   actual to each variant. Each scenario also links its full
   [optimal_strategy.md] so reviewers can drill into per-Friday divergence,
   missed-trade ordering, and the implications block. Δ is rendered in
   percentage points (constrained - actual) — positive means the cascade
   ranking left return on the table; negative (rare) means the actual run
   outperformed the perfect-hindsight greedy fill under sizing caps. *)

(* The runner's [Optimal_types.optimal_summary.total_return_pct] is a fraction
   (e.g. 0.30 = +30%); the actual side's [actual.total_return_pct] is already a
   percentage (e.g. 30.0). Normalise both to percentage units before computing
   Δ so the headline rows are directly comparable. *)
let _opt_return_pct_pp (s : optimal_summary) = s.total_return_pct *. 100.0
let _fmt_pct_signed_pp v = sprintf "%+.2f%%" v
let _fmt_delta_pp_pct v = sprintf "%+.2f pp" v
let _fmt_optional_str = function Some s -> s | None -> "—"

let _opt_row ~label ~cur_str ~prior_str =
  sprintf "| %s | %s | %s |" label cur_str prior_str

let _opt_actual_str (run : scenario_run) =
  _fmt_pct_signed_pp run.actual.total_return_pct

let _opt_variant_str (run : scenario_run)
    ~(get : optimal_summary_pair -> optimal_summary) =
  match run.optimal_strategy with
  | None -> "—"
  | Some pair -> _fmt_pct_signed_pp (_opt_return_pct_pp (get pair))

let _opt_delta_str (run : scenario_run)
    ~(get : optimal_summary_pair -> optimal_summary) =
  match run.optimal_strategy with
  | None -> "—"
  | Some pair ->
      let actual = run.actual.total_return_pct in
      let opt = _opt_return_pct_pp (get pair) in
      _fmt_delta_pp_pct (opt -. actual)

let _opt_link_str (run : scenario_run) =
  Option.map run.optimal_strategy ~f:(fun pair ->
      sprintf "[optimal_strategy.md](%s)" pair.report_path)
  |> _fmt_optional_str

let _row_optimal_for_pair (cur, prior) =
  [
    sprintf "### %s" cur.name;
    "";
    sprintf "Report — Current: %s · Prior: %s" (_opt_link_str cur)
      (_opt_link_str prior);
    "";
    "| Metric | Current | Prior |";
    "|---|---:|---:|";
    _opt_row ~label:"Actual total return" ~cur_str:(_opt_actual_str cur)
      ~prior_str:(_opt_actual_str prior);
    _opt_row ~label:"Optimal (constrained)"
      ~cur_str:(_opt_variant_str cur ~get:(fun p -> p.constrained))
      ~prior_str:(_opt_variant_str prior ~get:(fun p -> p.constrained));
    _opt_row ~label:"Δ to constrained"
      ~cur_str:(_opt_delta_str cur ~get:(fun p -> p.constrained))
      ~prior_str:(_opt_delta_str prior ~get:(fun p -> p.constrained));
    _opt_row ~label:"Optimal (relaxed macro)"
      ~cur_str:(_opt_variant_str cur ~get:(fun p -> p.relaxed_macro))
      ~prior_str:(_opt_variant_str prior ~get:(fun p -> p.relaxed_macro));
    _opt_row ~label:"Δ to relaxed"
      ~cur_str:(_opt_delta_str cur ~get:(fun p -> p.relaxed_macro))
      ~prior_str:(_opt_delta_str prior ~get:(fun p -> p.relaxed_macro));
    "";
  ]

let _optimal_strategy_section paired =
  let with_optimal =
    List.filter paired ~f:(fun (c, p) ->
        Option.is_some c.optimal_strategy || Option.is_some p.optimal_strategy)
  in
  if List.is_empty with_optimal then []
  else
    let header =
      [
        "## Optimal-strategy delta";
        "";
        "Counterfactual comparison against the perfect-hindsight greedy fill \
         under the same sizing envelope (`optimal_summary.sexp` required). Δ \
         is constrained-counterfactual minus actual, in percentage points — \
         positive means the cascade ranking left return on the table; negative \
         (rare) means the actual run outperformed the counterfactual under \
         sizing caps. Per-Friday divergence detail lives in the linked \
         `optimal_strategy.md`.";
        "";
      ]
    in
    let body = List.concat_map with_optimal ~f:_row_optimal_for_pair in
    header @ body

let render ?(thresholds = default_thresholds) (t : t) =
  let lines =
    _section_header ~title:"Release perf report" ~current:t.current_label
      ~prior:t.prior_label
    @ _trading_section t.paired
    @ _trade_quality_section t.paired
    @ _optimal_strategy_section t.paired
    @ _rss_section ~thresholds t.paired
    @ _wall_section ~thresholds t.paired
    @ _one_sided_section ~title:"Current-only scenarios" t.current_only
    @ _one_sided_section ~title:"Prior-only scenarios" t.prior_only
  in
  String.concat ~sep:"\n" lines ^ "\n"
