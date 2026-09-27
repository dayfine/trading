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

(** {1 [tightened_can_ratchet]} *)

val ratchet_tightened_swing :
  config:Stop_types.config ->
  side:position_side ->
  stop_level:float ->
  last_correction_extreme:float ->
  swing_peak:float option ->
  reason:string ->
  bar:Types.Daily_price.t ->
  Stop_types.stop_state * Stop_types.stop_event
(** One bar of the topping-zone reaction-low ratchet for a [Tightened] state,
    called (instead of the frozen running-min ratchet) when
    [config.tightened_can_ratchet] is on and the stop was not hit. The result
    is always [Tightened] with [swing_peak = Some _].

    - [swing_peak = None] (the bar after tightening): start the swing — peak
      and low both at this bar's close; no stop move.
    - Otherwise let [low] = the deeper of [last_correction_extreme] and this
      bar's against-trend extreme. A reaction is {b confirmed} when
      [(peak -. low) /. peak >= config.tightened_min_reaction_pct] (mirrored
      for shorts) and this close is back at or beyond [peak] — the
      correction + recovery geometry of the [Trailing] cycle
      ({!Stop_geometry.is_recovery}), chosen because Ch. 6 raises to a
      correction low only after the stock "rallies well off the low" back
      toward the prior peak. On confirmation the candidate is
      {!Stop_geometry.tightened_stop_candidate} of [low] (tight buffer + round
      number nudge, no MA term — the book allows it above the MA); it is
      installed only when it beats the stop ([Stop_raised]), and the swing
      restarts at this close.
    - Not confirmed: a strictly new extreme close restarts the swing at that
      close (the low must follow its peak); otherwise peak and [low] carry
      forward. The stop never moves. *)
