open Core

type t = {
  stage3_recovery_pct : float;
  stage3_recovery_weeks : int;
  late_reentry_weeks : int;
  late_reentry_pct : float;
  late_stage2_weeks : int;
  late_stage2_lookback_weeks : int;
  stop_whipsaw_weeks : int;
  stop_whipsaw_pct : float;
}
[@@deriving show, sexp]

(* Default thresholds match the dispatch brief 2026-05-29: stage-3 recovery
   5% / 12 weeks; late re-entry 8 weeks / 10%; late Stage 2 entry 8 weeks
   past cyclical low (12-week lookback); stop whipsaw 4 weeks / 5%. The
   per-symbol stage strategy has no stop-loss, so the whipsaw thresholds
   are inert under the canonical input; they are exposed so the same tool
   can score other strategies. *)
let default =
  {
    stage3_recovery_pct = 0.05;
    stage3_recovery_weeks = 12;
    late_reentry_weeks = 8;
    late_reentry_pct = 0.10;
    late_stage2_weeks = 8;
    late_stage2_lookback_weeks = 12;
    stop_whipsaw_weeks = 4;
    stop_whipsaw_pct = 0.05;
  }
