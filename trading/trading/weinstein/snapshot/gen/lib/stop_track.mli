(** The persisted trailing-stop state of one held position, threaded from week
    to week (weekly-snapshot item 4c.b).

    {1 Why this exists}

    Phase A showed a {b recomputed} stop floor beside the trader's working stop:
    every week {!Stop_recompute.for_held_long} derived a fresh support floor
    from the current bars. That is stateless, so the report could say "this
    week's floor is $x" but never "the stop has ratcheted up through three
    correction cycles and now sits at $x", and nothing carried the ratchet
    forward between runs.

    A track is that carried-forward state. It wraps
    {!Weinstein_stops.stop_state} — the real Weinstein trailing-stop state
    machine, already used by the live/backtest strategy — {b verbatim}, rather
    than mirroring it into a local shape. A parallel model of a three-arm
    variant would drift from the machine it is supposed to describe, and a
    mirror cannot be fed back into {!Weinstein_stops.update} without a lossy
    conversion.

    {1 The one invariant: never lowered}

    {!ratchet} is the single implementation of the never-lower rule
    (weinstein-book-reference.md §5.2 "Trailing Stop — Investor Method":
    "Continue moving the sell-stop up as the MA advances"; §5.4 "Don't hold
    hoping it will come back"). Both the manual-edit path
    ({!Portfolio_edit.adjust}) and the seeding path ({!Stop_thread.seed}) go
    through it, so there is exactly one monotonicity check to test and exactly
    one to break.

    Long-only, as the live held book is. *)

open Core

type t = {
  state : Weinstein_stops.stop_state;
      (** The state machine's own state, stored as-is. *)
  updated : Date.t;
      (** Week-ending date the state was last advanced through.
          {!Stop_thread.advance} replays only weeks after this date, which makes
          re-running a week idempotent. *)
  raises : int;
      (** Count of {!Weinstein_stops.Stop_raised} events since the track was
          seeded. This is the history the recomputed-floor design could not
          express: it distinguishes "the stop has been trailing up for several
          cycles" from "the floor happens to be here this week". *)
}
[@@deriving sexp, eq, show]

val level : t -> float
(** [level t] is the stop price currently in force, from whichever state arm the
    track holds. *)

val state_name : Weinstein_stops.stop_state -> string
(** ["Initial"] / ["Trailing"] / ["Tightened"] — the state-machine arm, without
    its payload. *)

val label : t -> string
(** A one-line human description of the track for the weekly report, e.g.
    ["Trailing (2 raises, through 2026-07-24)"]. *)

val ratchet : t -> to_:float -> t option
(** [ratchet t ~to_] raises the stop in force to [to_], keeping the state arm
    and all of its other bookkeeping (correction extremes, cycle count, MA
    reference) intact.

    Returns [None] when [to_] is {b strictly below} {!level} — the never-lower
    rule. Equality returns [Some t] unchanged, so re-applying the same stop is
    idempotent rather than an error.

    Note that a raise deliberately does {b not} bump {!raises}: that counter
    records adjustments the state machine made from price action, so that a
    manual edit cannot inflate the ratchet history the report describes. *)
