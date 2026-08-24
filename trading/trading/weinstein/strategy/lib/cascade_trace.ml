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
      { Audit_recorder.analysis; sector; side; outcome })

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

type t = {
  enabled : bool;
  cascade : (Stock_analysis.t * Screener.sector_context) list ref;
  walk : Audit_recorder.alternative_input list ref;
}

let create (recorder : Audit_recorder.t) =
  { enabled = recorder.capture_candidates; cascade = ref []; walk = ref [] }

let on_candidates t =
  if t.enabled then Some (fun cs -> t.cascade := cs) else None

let on_walk_candidates t =
  if t.enabled then Some (fun alts -> t.walk := alts) else None

let _drops t ~config ~macro_trend ~result =
  if not t.enabled then []
  else of_screen ~config ~macro_trend ~candidates:!(t.cascade) ~result

let record t ~(audit_recorder : Audit_recorder.t) ~date ~config ~macro_trend
    ~(result : Screener.result) ~entered =
  audit_recorder.record_cascade_summary
    {
      date;
      diagnostics = result.cascade_diagnostics;
      entered;
      candidates = !(t.walk);
      drops = _drops t ~config ~macro_trend ~result;
    }
