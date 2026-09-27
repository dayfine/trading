(** Anchor-bookkeeping rules for the stop state machine that sit behind
    default-off config flags (issue #2974). Kept out of {!Weinstein_stops} so the
    coordinator stays under its file-length cap; every function here returns the
    pre-flag value when its flag is off. *)

open Trading_base.Types

(** {1 [correction_must_follow_peak]} *)

val seed_correction_extreme :
  config:Stop_types.config ->
  side:position_side ->
  bar:Types.Daily_price.t ->
  float
(** The [last_correction_extreme] seeded on the [Initial -> Trailing]
    transition. Flag off: the bar's against-trend extreme (low for a long, high
    for a short) — a price printed {e before} the bar's close, which is the
    seeded trend extreme. Flag on: the bar's close, so the running correction
    extreme starts at the peak and only a later bar can deepen it. *)

val carried_correction_extreme :
  config:Stop_types.config ->
  side:position_side ->
  last_trend_extreme:float ->
  new_trend_extreme:float ->
  new_correction_extreme:float ->
  bar:Types.Daily_price.t ->
  float
(** The [last_correction_extreme] a [Trailing] state carries to the next bar
    when no cycle reset happened on this one. Flag off: [new_correction_extreme]
    unchanged (the running extreme since the last reset, which may predate the
    current peak). Flag on: when this bar printed a new trend extreme (a closing
    high strictly above [last_trend_extreme] for a long, a closing low strictly
    below it for a short), the correction is measured afresh from that peak —
    the carried extreme resets to the bar's close; otherwise
    [new_correction_extreme]. Called {e after} the bar's cycle check, so a
    correction that completes on a new-high bar is still seen in full. *)
