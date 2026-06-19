(** Round-number stop nudging.

    Round numbers and half-dollars attract heavy order flow, so stops placed
    right at those levels are more likely to be triggered by noise. This steps a
    raw stop just outside the nearest level. Extracted from [weinstein_stops.ml]
    to keep that coordinator module under the file-length cap. *)

val nudge_round_number :
  nudge:float -> side:Trading_base.Types.position_side -> float -> float
(** [nudge_round_number ~nudge ~side price] returns [price] stepped just outside
    the nearest half-dollar when it lands within [nudge] of one: for a [Long]
    the stop moves {b below} the level (by [nudge]), for a [Short] {b above} it.
    When [price] is farther than [nudge] from the nearest half-dollar, it is
    returned unchanged. *)
