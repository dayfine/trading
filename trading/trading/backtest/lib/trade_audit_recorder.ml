(** Backtest-side recorder: drains strategy events into a {!Trade_audit.t}
    collector. See [trade_audit_recorder.mli]. *)

open Core
module AR = Weinstein_strategy.Audit_recorder

let _stop_floor_kind_of_event = function
  | AR.Support_floor -> Trade_audit.Support_floor
  | AR.Buffer_fallback -> Trade_audit.Buffer_fallback

let _skip_reason_of_event = function
  | AR.Insufficient_cash -> Trade_audit.Insufficient_cash
  | AR.Already_held -> Trade_audit.Already_held
  | AR.Sized_to_zero -> Trade_audit.Sized_to_zero

let _alternative_of_event (alt : AR.alternative_input) :
    Trade_audit.alternative_candidate =
  {
    symbol = alt.candidate.ticker;
    side = alt.candidate.side;
    score = alt.candidate.score;
    grade = alt.candidate.grade;
    reason_skipped = _skip_reason_of_event alt.reason;
  }

(** Translate one {!AR.entry_event} into a {!Trade_audit.entry_decision}. Pure
    projection — every field is derived from the event. *)
let _entry_decision_of_event (e : AR.entry_event) : Trade_audit.entry_decision =
  let cand = e.candidate in
  let analysis = cand.analysis in
  {
    symbol = cand.ticker;
    entry_date = e.current_date;
    position_id = e.position_id;
    macro_trend = e.macro.trend;
    macro_confidence = e.macro.confidence;
    macro_indicators = e.macro.indicators;
    stage = analysis.stage.stage;
    ma_direction = analysis.stage.ma_direction;
    ma_slope_pct = analysis.stage.ma_slope_pct;
    rs_trend = Option.map analysis.rs ~f:(fun (r : Rs.result) -> r.trend);
    rs_value =
      Option.map analysis.rs ~f:(fun (r : Rs.result) -> r.current_normalized);
    volume_quality =
      Option.map analysis.volume ~f:(fun (v : Volume.result) -> v.confirmation);
    resistance_quality =
      Option.map analysis.resistance ~f:(fun (r : Resistance.result) ->
          r.quality);
    support_quality =
      Option.map analysis.support ~f:(fun (s : Support.result) -> s.quality);
    sector_name = cand.sector.sector_name;
    sector_rating = cand.sector.rating;
    cascade_score = cand.score;
    cascade_grade = cand.grade;
    cascade_score_components = [];
    (* PR-3 will split the screener's score into per-component contributions.
       Until then the [rationale] string list conveys the contributing signals
       in human-readable form. *)
    cascade_rationale = cand.rationale;
    side = cand.side;
    suggested_entry = cand.suggested_entry;
    suggested_stop = cand.suggested_stop;
    installed_stop = e.installed_stop;
    stop_floor_kind = _stop_floor_kind_of_event e.stop_floor_kind;
    risk_pct = cand.risk_pct;
    initial_position_value = e.initial_position_value;
    initial_risk_dollars = e.initial_risk_dollars;
    alternatives_considered = List.map e.alternatives ~f:_alternative_of_event;
  }

(** Translate one {!AR.exit_event} into a {!Trade_audit.exit_decision}.

    The during-hold counters ([max_favorable_excursion_pct],
    [max_adverse_excursion_pct], [weeks_macro_was_bearish],
    [weeks_stage_left_2]) are filled with sensible defaults — populating them
    requires per-step instrumentation through the simulator's step stream, which
    is deferred to a follow-up PR. The state-at-decision fields (macro / stage /
    rs / distance_from_ma) are populated from the strategy's snapshot captured
    at the moment the [TriggerExit] fired. *)
let _exit_decision_of_event (e : AR.exit_event) : Trade_audit.exit_decision =
  {
    symbol = e.symbol;
    exit_date = e.exit_date;
    position_id = e.position_id;
    exit_trigger = Stop_log.exit_trigger_of_reason e.exit_reason;
    macro_trend_at_exit = e.macro_trend_at_exit;
    macro_confidence_at_exit = e.macro_confidence_at_exit;
    stage_at_exit = e.stage_at_exit;
    rs_trend_at_exit = e.rs_trend_at_exit;
    distance_from_ma_pct = e.distance_from_ma_pct;
    max_favorable_excursion_pct = 0.0;
    max_adverse_excursion_pct = 0.0;
    weeks_macro_was_bearish = 0;
    weeks_stage_left_2 = 0;
  }

let of_collector (collector : Trade_audit.t) : AR.t =
  {
    record_entry =
      (fun event ->
        Trade_audit.record_entry collector (_entry_decision_of_event event));
    record_exit =
      (fun event ->
        Trade_audit.record_exit collector (_exit_decision_of_event event));
  }
