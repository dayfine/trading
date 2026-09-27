open Core

(* --- Trade quality summary ---

   For each pair with a [trade_quality] record on either side, surface the
   headline behavioural / Weinstein-conformance numbers + delta: flat
   returns can still hide a regressing trade quality. *)

type trade_quality_pair = {
  name : string;
  current : Trade_audit_report.t option;
  prior : Trade_audit_report.t option;
}

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

let _row_quality_for_pair (p : trade_quality_pair) =
  let cur_q = _summarize_quality p.current in
  let prior_q = _summarize_quality p.prior in
  [
    sprintf "### %s" p.name;
    "";
    "| Metric | Current | Prior | \xce\x94 |";
    "|---|---:|---:|---:|";
  ]
  @ _quality_rows ~cur:cur_q ~prior:prior_q
  @ [ "" ]

let render_trade_quality pairs =
  let with_quality =
    List.filter pairs ~f:(fun p ->
        Option.is_some p.current || Option.is_some p.prior)
  in
  if List.is_empty with_quality then []
  else
    let header =
      [
        "## Trade quality";
        "";
        "Behavioural metrics + Weinstein conformance per scenario \
         (`trade_audit.sexp` required). \xce\x94 is current minus prior — \
         lower exit-winners-flagged / exit-losers-flagged is better; higher \
         spirit score and mean R-multiple is better.";
        "";
      ]
    in
    let body = List.concat_map with_quality ~f:_row_quality_for_pair in
    header @ body

(* --- Optimal-strategy counterfactual delta section ---

   For each pair with [Some _] optimal-strategy artefacts, surface the
   constrained + relaxed-macro counterfactual returns next to the actual
   return, plus per-side Δ (pp) from actual to each variant, with a link to
   the full [optimal_strategy.md] drill-down. Positive Δ means the cascade
   ranking left return on the table. *)

type optimal_variant = { constrained_pct : float; relaxed_pct : float }

type optimal_side = {
  actual_total_return_pct : float;
  optimal : optimal_variant option;
  report_link : string option;
}

type optimal_pair = {
  opt_name : string;
  opt_current : optimal_side;
  opt_prior : optimal_side;
}

let _fmt_pct_signed_pp v = sprintf "%+.2f%%" v
let _fmt_delta_pp_pct v = sprintf "%+.2f pp" v
let _fmt_optional_str = function Some s -> s | None -> "—"

let _opt_row ~label ~cur_str ~prior_str =
  sprintf "| %s | %s | %s |" label cur_str prior_str

let _opt_actual_str (side : optimal_side) =
  _fmt_pct_signed_pp side.actual_total_return_pct

let _opt_variant_str (side : optimal_side) ~(get : optimal_variant -> float) =
  match side.optimal with None -> "—" | Some v -> _fmt_pct_signed_pp (get v)

let _opt_delta_str (side : optimal_side) ~(get : optimal_variant -> float) =
  match side.optimal with
  | None -> "—"
  | Some v -> _fmt_delta_pp_pct (get v -. side.actual_total_return_pct)

let _opt_link_str (side : optimal_side) =
  Option.map side.report_link ~f:(sprintf "[optimal_strategy.md](%s)")
  |> _fmt_optional_str

let _row_optimal_for_pair (p : optimal_pair) =
  [
    sprintf "### %s" p.opt_name;
    "";
    sprintf "Report — Current: %s · Prior: %s"
      (_opt_link_str p.opt_current)
      (_opt_link_str p.opt_prior);
    "";
    "| Metric | Current | Prior |";
    "|---|---:|---:|";
    _opt_row ~label:"Actual total return"
      ~cur_str:(_opt_actual_str p.opt_current)
      ~prior_str:(_opt_actual_str p.opt_prior);
    _opt_row ~label:"Optimal (constrained)"
      ~cur_str:
        (_opt_variant_str p.opt_current ~get:(fun v -> v.constrained_pct))
      ~prior_str:
        (_opt_variant_str p.opt_prior ~get:(fun v -> v.constrained_pct));
    _opt_row ~label:"\xce\x94 to constrained"
      ~cur_str:(_opt_delta_str p.opt_current ~get:(fun v -> v.constrained_pct))
      ~prior_str:(_opt_delta_str p.opt_prior ~get:(fun v -> v.constrained_pct));
    _opt_row ~label:"Optimal (relaxed macro)"
      ~cur_str:(_opt_variant_str p.opt_current ~get:(fun v -> v.relaxed_pct))
      ~prior_str:(_opt_variant_str p.opt_prior ~get:(fun v -> v.relaxed_pct));
    _opt_row ~label:"\xce\x94 to relaxed"
      ~cur_str:(_opt_delta_str p.opt_current ~get:(fun v -> v.relaxed_pct))
      ~prior_str:(_opt_delta_str p.opt_prior ~get:(fun v -> v.relaxed_pct));
    "";
  ]

let render_optimal_strategy pairs =
  let with_optimal =
    List.filter pairs ~f:(fun p ->
        Option.is_some p.opt_current.optimal
        || Option.is_some p.opt_prior.optimal)
  in
  if List.is_empty with_optimal then []
  else
    let header =
      [
        "## Optimal-strategy delta";
        "";
        "Counterfactual comparison against the perfect-hindsight greedy fill \
         under the same sizing envelope (`optimal_summary.sexp` required). \
         \xce\x94 is constrained-counterfactual minus actual, in percentage \
         points — positive means the cascade ranking left return on the table; \
         negative (rare) means the actual run outperformed the counterfactual \
         under sizing caps. Per-Friday divergence detail lives in the linked \
         `optimal_strategy.md`.";
        "";
      ]
    in
    let body = List.concat_map with_optimal ~f:_row_optimal_for_pair in
    header @ body
