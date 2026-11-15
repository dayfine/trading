(** Per-Friday candidate capture. See [cascade_trace.mli]. *)

open Core

let _long_macro_admits (trend : Weinstein_types.market_trend) =
  match trend with Bearish -> false | Bullish | Neutral -> true

let _short_macro_admits (trend : Weinstein_types.market_trend) =
  match trend with Bullish -> false | Bearish | Neutral -> true

let _tickers_of candidates =
  String.Set.of_list
    (List.map candidates ~f:(fun (c : Screener.scored_candidate) -> c.ticker))

(* Pair each outcome back to the analysis it came from. [long_outcomes] /
   [short_outcomes] preserve [candidates] order, so a positional zip is exact
   and avoids a ticker-keyed lookup that would misbehave on a duplicate. *)
let _drops_of_outcomes ~side ~candidates outcomes =
  List.map2_exn candidates outcomes
    ~f:(fun (analysis, sector) (outcome : Screener.candidate_outcome) ->
      { Audit_recorder.analysis; sector; side; outcome; top_n = None })

let _long_drops ~(config : Screener.config) ~macro_trend ~candidates
    ~(result : Screener.result) =
  if not (_long_macro_admits macro_trend) then []
  else
    Screener.long_outcomes ~weights:config.weights
      ~thresholds:config.grade_thresholds ~min_grade:config.min_grade
      ~min_score_override:config.min_score_override
      ~max_score_override:config.max_score_override
      ~volume_ratio_exclude_range:config.volume_ratio_exclude_range
      ~min_price:config.min_price
      ~failed_breakout_tolerance_pct:config.failed_breakout_tolerance_pct
      ~early_stage2_max_weeks:config.early_stage2_max_weeks
      ~min_rs_normalized:config.min_rs_normalized ~macro_admits:true
      ~top_n_tickers:(_tickers_of result.buy_candidates)
      ~candidates
    |> _drops_of_outcomes ~side:Trading_base.Types.Long ~candidates

let _short_drops ~(config : Screener.config) ~macro_trend ~candidates
    ~(result : Screener.result) =
  if not (_short_macro_admits macro_trend) then []
  else
    Screener.short_outcomes ~weights:config.weights
      ~thresholds:config.grade_thresholds ~min_grade:config.min_grade
      ~min_score_override:config.min_score_override
      ~max_score_override:config.max_score_override
      ~volume_ratio_exclude_range:config.volume_ratio_exclude_range
      ~min_price:config.min_price ~macro_admits:true
      ~top_n_tickers:(_tickers_of result.short_candidates)
      ~candidates
    |> _drops_of_outcomes ~side:Trading_base.Types.Short ~candidates

let of_screen ~config ~macro_trend ~candidates ~result =
  _long_drops ~config ~macro_trend ~candidates ~result
  @ _short_drops ~config ~macro_trend ~candidates ~result

let shadow_verdict (report : Entry_walk.walk_report)
    (cand : Screener.scored_candidate) : Audit_recorder.Top_n.shadow =
  if Set.mem report.held cand.ticker then Already_held
  else
    let c = report.stop_check cand in
    match c.decision with
    | Lacks_structural_stop -> No_structural_stop
    | Width Drop -> Stop_too_wide c.stops.gate_distance_pct
    | Width (Admit | Admit_sized_down) -> Buyable c.stops.gate_distance_pct

(* The two skips the walk takes before building any stop. *)
let _walk_built_a_stop : Audit_recorder.walk_outcome -> bool = function
  | Skipped (Already_held | Share_class_held) -> false
  | Placed
  | Skipped
      ( Insufficient_cash | Sized_to_zero | Short_notional_cap | Stop_too_wide
      | Sector_exposure_cap | Long_exposure_cap | No_structural_stop _ ) ->
      true

let _same_row (d : Audit_recorder.cascade_drop)
    (w : Audit_recorder.walk_decision) =
  String.equal w.ranked.ticker d.outcome.ticker
  && Trading_base.Types.equal_position_side w.ranked.side d.side

(* An [Admitted] row's walk outcome, re-asking the walk's stop check of the
   candidate exactly as the walk classified it ([w.ranked]). *)
let _walked ~decisions ~(report : Entry_walk.walk_report) d :
    Audit_recorder.Top_n.verdict =
  match List.find decisions ~f:(_same_row d) with
  | None -> Not_reached
  | Some (w : Audit_recorder.walk_decision) ->
      let stop_distance_pct =
        if _walk_built_a_stop w.outcome then
          Some (report.stop_check w.ranked).stops.gate_distance_pct
        else None
      in
      Walked { outcome = w.outcome; stop_distance_pct }

(* Per side: ticker -> (1-based rank, the screener's own candidate). *)
let _rank_table ranked =
  List.mapi ranked ~f:(fun i (c : Screener.scored_candidate) ->
      (c.ticker, (i + 1, c)))
  |> String.Map.of_alist_reduce ~f:(fun first _ -> first)

let _top_n_of ~ranks:(longs, shorts) ~decisions ~report
    (d : Audit_recorder.cascade_drop) =
  let table = match d.side with Long -> longs | Short -> shorts in
  let view verdict_of =
    Option.map (Map.find table d.outcome.ticker) ~f:(fun (rank, cand) ->
        { Audit_recorder.Top_n.rank; verdict = verdict_of cand })
  in
  match d.outcome.phase with
  | Admitted -> view (fun _ -> _walked ~decisions ~report d)
  | Dropped_at_top_n -> view (fun cand -> Shadow (shadow_verdict report cand))
  | Dropped_at_macro | Dropped_at_breakout _ | Dropped_at_sector | Dropped_at_rs
  | Dropped_at_grade ->
      None

let with_top_n ~config ~date ~candidates ~decisions ~report drops =
  let longs, shorts = Screener.rank_survivors ~config ~as_of:date ~candidates in
  let ranks = (_rank_table longs, _rank_table shorts) in
  List.map drops ~f:(fun (d : Audit_recorder.cascade_drop) ->
      { d with top_n = _top_n_of ~ranks ~decisions ~report d })

type t = {
  enabled : bool;
  cascade : (Stock_analysis.t * Screener.sector_context) list ref;
  walk : Audit_recorder.walk_decision list ref;
  report : Entry_walk.walk_report option ref;
}

let create (recorder : Audit_recorder.t) =
  {
    enabled = recorder.capture_candidates;
    cascade = ref [];
    walk = ref [];
    report = ref None;
  }

let on_candidates t =
  if t.enabled then Some (fun cs -> t.cascade := cs) else None

(* Always installed (#3139): the weekly decision record is unconditional. *)
let on_walk_candidates t = Some (fun decisions -> t.walk := decisions)

let on_walk_report t =
  if t.enabled then Some (fun report -> t.report := Some report) else None

(* The pre-#3139 [candidates] projection: the passed-over rows, capture only. *)
let _passed_over t =
  if not t.enabled then []
  else
    List.filter_map !(t.walk) ~f:(fun (d : Audit_recorder.walk_decision) ->
        match d.outcome with
        | Skipped reason -> Some { Audit_recorder.candidate = d.ranked; reason }
        | Placed -> None)

let _drops t ~config ~macro_trend ~result ~date =
  if not t.enabled then []
  else
    let candidates = !(t.cascade) in
    let drops = of_screen ~config ~macro_trend ~candidates ~result in
    match !(t.report) with
    | None -> drops
    | Some report ->
        with_top_n ~config ~date ~candidates ~decisions:!(t.walk) ~report drops

let record t ~(audit_recorder : Audit_recorder.t) ~date ~config
    ~(macro : Macro.result) ~(result : Screener.result) ~entered =
  audit_recorder.record_cascade_summary
    {
      date;
      diagnostics = result.cascade_diagnostics;
      breadth_state = macro.breadth_state;
      entered;
      candidates = _passed_over t;
      decisions = !(t.walk);
      drops = _drops t ~config ~macro_trend:macro.trend ~result ~date;
      long_cash_left_pct =
        Option.map !(t.report) ~f:(fun (r : Entry_walk.walk_report) ->
            r.long_cash_left_pct);
    }
