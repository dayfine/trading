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

    {1 The invariant: never lowered}

    Weinstein's trailing stop moves up as the MA advances and is never moved
    against the position (weinstein-book-reference.md §5.2 "Trailing Stop —
    Investor Method": "Continue moving the sell-stop up as the MA advances";
    §5.4 "Don't hold hoping it will come back").

    The rule is enforced in {b two} places, because there are two different
    numbers to guard:

    - {!ratchet} guards this track's [state] — the {e machine's} stop level. It
      returns [None] rather than lowering, and is the only way to move that
      level, so it is the only place the rule can be bypassed for the machine.
      Its callers are {!Portfolio_edit.adjust} (on a manual raise) and
      {!Stop_thread.seed} (so seeding cannot drop below the working stop).
    - [Portfolio_edit._check_stop_not_lowered] guards
      [Live_portfolio.position.stop_price] — the {e trader's} working broker
      order, which is the field the [record_fill adjust] CLI edits.

    They are deliberately not merged. The CLI check has to name the offending
    values in an error message and has to be overridable by [--allow-lower-stop]
    for a mistyped stop; an [option]-returning ratchet can express neither, and
    making it try would put CLI wording in this module. Each has its own test —
    [ratchet_refuses_a_lower_level] here, [adjust_rejects_lowered_stop] in
    [test_portfolio_edit].

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
