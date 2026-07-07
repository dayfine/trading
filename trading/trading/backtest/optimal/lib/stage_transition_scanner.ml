(** Phase A scanner for the optimal-strategy counterfactual.

    See [stage_transition_scanner.mli] for the API contract.

    Implementation strategy: invoke {!Screener.screen} per Friday with a
    *permissive* config — [min_grade = F], unlimited top-N, and a forced
    [Neutral] macro trend — so the cascade emits one [scored_candidate] per
    breakout-passing analysis without dropping any to grade / top-N / macro
    gates. The actual macro trend ([week.macro_trend]) is consulted separately
    to set [passes_macro] on each emitted candidate.

    This keeps the scanner aligned with the live cascade's per-candidate price
    and grade arithmetic byte-for-byte (it calls the same code) while bypassing
    the gates the counterfactual deliberately relaxes. *)

open Core

type week_input = {
  date : Date.t;
  macro_trend : Weinstein_types.market_trend;
  analyses : Stock_analysis.t list;
  sector_map : (string, Screener.sector_context) Hashtbl.t;
}

type config = {
  scoring_weights : Screener.scoring_weights;
  grade_thresholds : Screener.grade_thresholds;
  candidate_params : Screener.candidate_params;
}

let config_of_screener_config (c : Screener.config) : config =
  {
    scoring_weights = c.weights;
    grade_thresholds = c.grade_thresholds;
    candidate_params = c.candidate_params;
  }

(** Build the permissive {!Screener.config} the scanner uses internally. *)
let _permissive_screener_config (config : config) : Screener.config =
  {
    weights = config.scoring_weights;
    grade_thresholds = config.grade_thresholds;
    candidate_params = config.candidate_params;
    min_grade = F;
    candidate_ranking = Screener.Alphabetical;
    min_score_override = None;
    max_score_override = None;
    volume_ratio_exclude_range = None;
    max_buy_candidates = Int.max_value;
    max_short_candidates = Int.max_value;
    cascade_post_stop_cooldown_weeks = 0;
    neutral_blocks_longs = false;
    neutral_blocks_shorts = false;
    enable_slow_grind_short_gate = false;
    min_price = 0.0;
    early_stage2_max_weeks = 4;
  }

(** Whether [trend] would have admitted longs at the macro gate. *)
let _passes_long_macro = function
  | Weinstein_types.Bullish | Neutral -> true
  | Bearish -> false

(** [(weeks_advancing, late)] of a [Stage2] classification, [(None, None)]
    otherwise. Mirrors {!Trade_audit_recorder._weeks_advancing_of_stage} — the
    two Stage2-only fields the counterfactual surfaces for the multivariate
    screen. *)
let _stage2_fields : Weinstein_types.stage -> int option * bool option =
  function
  | Stage2 { weeks_advancing; late } -> (Some weeks_advancing, Some late)
  | Stage1 _ | Stage3 _ | Stage4 _ -> (None, None)

(** Project one {!Screener.scored_candidate} (long side) into an
    {!Optimal_types.candidate_entry}, stamping the actual macro at [date] and
    the decision-time features from [sc.analysis]. The feature projections
    mirror {!Trade_audit_recorder._entry_decision_of_event} field-for-field so
    the two audit surfaces read the same values. *)
let _candidate_of_scored ~date ~passes_macro (sc : Screener.scored_candidate) :
    Optimal_types.candidate_entry =
  let analysis = sc.analysis in
  let weeks_advancing, stage2_late = _stage2_fields analysis.stage.stage in
  {
    symbol = sc.ticker;
    entry_week = date;
    side = sc.side;
    entry_price = sc.suggested_entry;
    suggested_stop = sc.suggested_stop;
    risk_pct = sc.risk_pct;
    sector = sc.sector.sector_name;
    cascade_grade = sc.grade;
    cascade_score = sc.score;
    passes_macro;
    rs_value =
      Option.map analysis.rs ~f:(fun (r : Rs.result) -> r.current_normalized);
    rs_trend = Option.map analysis.rs ~f:(fun (r : Rs.result) -> r.trend);
    volume_ratio =
      Option.map analysis.volume ~f:(fun (v : Volume.result) -> v.volume_ratio);
    weeks_advancing;
    stage2_late;
    resistance_quality =
      Option.map analysis.resistance ~f:(fun (r : Resistance.result) ->
          r.quality);
  }

let scan_week ~config (week : week_input) : Optimal_types.candidate_entry list =
  let permissive = _permissive_screener_config config in
  (* Force [Neutral] so both long and short cascades stay open; the actual
     macro is captured per candidate via [passes_macro]. *)
  let result =
    Screener.screen ~config:permissive ~macro_trend:Neutral
      ~sector_map:week.sector_map ~stocks:week.analyses ~held_tickers:[]
  in
  let passes_macro = _passes_long_macro week.macro_trend in
  List.map result.buy_candidates
    ~f:(_candidate_of_scored ~date:week.date ~passes_macro)

let scan_panel ~config (weeks : week_input list) :
    Optimal_types.candidate_entry list =
  List.concat_map weeks ~f:(fun w -> scan_week ~config w)
