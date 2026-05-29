(** Per-mode failure classifiers and missed-gain computation helpers.

    Pure functions. All thresholds come from {!Trade_autopsy_config.t}. *)

open Core
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

type weekly_bar = Types.Daily_price.t

val weeks_between :
  bars:weekly_bar list -> from_date:Date.t -> to_date:Date.t -> int option
(** [weeks_between ~bars ~from_date ~to_date] returns the index distance between
    the bars matching [from_date] and [to_date]. [None] if either date is not in
    [bars]. *)

val weeks_held : weekly_bars:weekly_bar list -> trade:Walk_step.trade -> int
(** [weeks_held ~weekly_bars ~trade] returns the number of weekly bars between
    the trade's entry and exit dates. Returns 0 if either date is not in
    [weekly_bars]. *)

val weeks_since_cyclical_low :
  config:Trade_autopsy_config.t ->
  weekly_bars:weekly_bar list ->
  trade:Walk_step.trade ->
  int option
(** [weeks_since_cyclical_low ~config ~weekly_bars ~trade] returns the number of
    weekly bars between the prior cyclical low (in the
    [late_stage2_lookback_weeks] window before entry) and the trade's entry
    date. [None] for short trades (concept does not apply) or if the lookback is
    incomplete. *)

val compute_missed_gain_and_reentry :
  weekly_bars:weekly_bar list ->
  trades:Walk_step.trade list ->
  exit_reason:Exit_reason.t ->
  trade:Walk_step.trade ->
  float * Date.t option * int option
(** [compute_missed_gain_and_reentry ~weekly_bars ~trades ~exit_reason ~trade]
    returns [(missed_gain_pct, next_entry_date, weeks_to_reentry)] for [trade].

    Reference price for missed-gain: either (a) the next same-side entry price,
    if such an entry exists in [trades], or (b) the end-of-window close, if no
    same-side re-entry happens. [End_of_period] trades report
    [missed_gain = 0.0] — there is no forward window to evaluate.

    For long trades: positive missed_gain means price ran up after exit (missed
    upside). For short trades: positive means price kept declining (missed
    downside the short would have captured). *)

val stage3_false_positive :
  config:Trade_autopsy_config.t ->
  weekly_bars:weekly_bar list ->
  exit_reason:Exit_reason.t ->
  trade:Walk_step.trade ->
  bool
(** [stage3_false_positive] returns [true] iff [exit_reason = Stage3_exit] AND
    the symbol's close [stage3_recovery_weeks] later is at least
    [exit_price * (1 + stage3_recovery_pct)]. End-of-period trades are never
    counted (no forward window to evaluate). *)

val late_reentry :
  config:Trade_autopsy_config.t ->
  weeks_to_reentry:int option ->
  missed_gain_pct:float ->
  bool
(** [late_reentry] returns [true] iff a same-side re-entry exists AND the gap
    exceeds [late_reentry_weeks] AND the missed_gain exceeds [late_reentry_pct].
*)

val late_stage2 :
  config:Trade_autopsy_config.t ->
  weeks_since_cyclical_low:int option ->
  trade:Walk_step.trade ->
  bool
(** [late_stage2] returns [true] iff the trade is LONG AND
    [weeks_since_cyclical_low] exceeds [late_stage2_weeks]. Short trades are
    never flagged. *)

val stop_whipsaw :
  config:Trade_autopsy_config.t ->
  weekly_bars:weekly_bar list ->
  exit_reason:Exit_reason.t ->
  trade:Walk_step.trade ->
  bool
(** [stop_whipsaw] returns [true] iff [exit_reason = Stop_out] AND the symbol's
    close [stop_whipsaw_weeks] later is at least
    [exit_price * (1 + stop_whipsaw_pct)]. INERT under the per-symbol stage
    strategy (which has no stops) but exposed for strategies that do. *)
