(** Side-aware arithmetic and predicates shared by every arm of the stop state
    machine.

    Extracted from {!Weinstein_stops} to keep that coordinator under the
    file-length cap. Every function here is pure and directional: [Long] and
    [Short] are exact mirrors, which is the property that lets the state machine
    itself carry a single code path for both sides. *)

open Stop_types
open Trading_base.Types

val nudge_round_number : config:config -> side:position_side -> float -> float
(** Apply {!Stop_nudge.nudge_round_number} at the config's [round_number_nudge]
    distance. The nudge only ever widens the effective buffer — it moves longs
    further down and shorts further up, never the reverse (book §5.1: place the
    stop just {i below} the round number, because buy orders accumulate there).
*)

val bar_extreme : side:position_side -> bar:Types.Daily_price.t -> float
(** The bar's extreme price in the against-trend direction.

    - [Long] → session low: how far price pulled back against the uptrend.
    - [Short] → session high: how far price counter-rallied against the
      downtrend.

    This is also the intra-bar stop trigger price: longs exit when the low
    reaches the stop level, shorts when the high does. *)

val stop_candidate :
  config:config -> side:position_side -> correction_extreme:float -> float
(** Trailing stop candidate from a correction extreme: apply
    [config.trailing_stop_buffer_pct] in the position's favour, then
    {!nudge_round_number}. *)

val tightened_stop_candidate :
  config:config -> side:position_side -> correction_extreme:float -> float
(** As {!stop_candidate} but with [config.tightened_stop_buffer_pct] — tighter
    than the trailing buffer, to keep the stop close to market once the
    [Tightened] state is entered. *)

val is_better_stop :
  side:position_side -> current:float -> candidate:float -> bool
(** Would [candidate] move the stop in the position's favour? Higher for a long,
    lower for a short. This is the never-lower rule (book §5.2, qc-behavioral
    L2) in predicate form: a candidate that fails it is discarded, never
    installed. *)

val is_correction :
  config:config ->
  side:position_side ->
  trend_extreme:float ->
  correction_extreme:float ->
  bool
(** Was the counter-move from [trend_extreme] to [correction_extreme] at least
    [config.min_correction_pct] deep? Book §5.2's "substantial correction
    (8-10%+)" gate. *)

val is_recovery :
  side:position_side -> close:float -> trend_extreme:float -> bool
(** Did this bar's close carry price back through the prior trend extreme —
    "rallies back near prior peak" for a long, the mirror for a short? Together
    with {!is_correction} this is the completed-cycle test. *)
