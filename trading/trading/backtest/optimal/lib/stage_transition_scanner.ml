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
    max_buy_candidates = Int.max_value;
    max_short_candidates = Int.max_value;
    cascade_post_stop_cooldown_weeks = 0;
  }

(** Whether [trend] would have admitted longs at the macro gate. *)
let _passes_long_macro = function
  | Weinstein_types.Bullish | Neutral -> true
  | Bearish -> false

(** Project one {!Screener.scored_candidate} (long side) into an
    {!Optimal_types.candidate_entry}, stamping the actual macro at [date]. *)
let _candidate_of_scored ~date ~passes_macro (sc : Screener.scored_candidate) :
    Optimal_types.candidate_entry =
  {
    symbol = sc.ticker;
    entry_week = date;
    side = sc.side;
    entry_price = sc.suggested_entry;
    suggested_stop = sc.suggested_stop;
    risk_pct = sc.risk_pct;
    sector = sc.sector.sector_name;
    cascade_grade = sc.grade;
    passes_macro;
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
