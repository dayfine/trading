(** Observability record for one advance of the trailing-stop state machine —
    what the stop was, what it became, and {b why} (issue #2977).

    Pure and read-only: {!classify} and {!make} re-derive the decision from the
    [(before, after, event, bar)] that {!Weinstein_stops.update} already
    returned. Nothing here feeds back into the state machine, so wiring it in
    cannot change any stop, fill or golden.

    The reason tags name what the state machine actually decided. For a
    [Trailing] state the cycle test is book §5.2's "raise the stop only after a
    correction (>= [min_correction_pct]) {i and} a recovery back through the
    prior peak", plus the post-reset phantom-cycle guard; each way that test can
    fail has its own tag, so a run's records separate "no qualifying correction
    happened" (faithful) from "a cycle completed and the ratchet did not move"
    (the #2974 question). *)

open Core
open Trading_base.Types

(** Why the stop moved, or did not, on this step. *)
type reason =
  | Raised
      (** [Trailing]: a correction cycle completed and its candidate improved
          the stop — the ratchet moved (event [Stop_raised]). *)
  | No_correction_yet
      (** [Trailing]: the counter-move from the trend extreme to the running
          correction extreme is shallower than [config.min_correction_pct]. The
          book's "hold the stop" case. *)
  | Correction_not_recovered
      (** [Trailing]: a deep-enough correction is on file but this bar's close
          has not recovered through the prior trend extreme yet. *)
  | Anchor_not_fresh
      (** [Trailing]: correction and recovery are both met, but after an earlier
          cycle reset no bar has touched the correction anchor since, so the
          phantom-cycle guard rejects the cycle. *)
  | Cycle_stalled
      (** [Trailing]: a cycle completed but its candidate is not above the
          current stop (the never-lower rule, book §5.2), so the stop stays.
          Covers both the bookkeeping-reset path
          ([reset_anchor_on_stalled_cycle = true]: [correction_count] advances)
          and the frozen path ([false]). *)
  | Seeded_trailing
      (** [Initial] -> [Trailing]: the first update after entry seeds the cycle
          tracking; the stop itself does not move. *)
  | Entered_tightening
      (** [Initial] / [Trailing] -> [Tightened]: Stage 3/4 or a flattening MA
          (event [Entered_tightening]). *)
  | Tightened_ratchet
      (** [Tightened]: the tight ratchet moved the stop (event [Stop_raised]).
      *)
  | Tightened_hold  (** [Tightened]: the tight ratchet had nothing to improve. *)
  | Stop_hit
      (** The bar crossed the stop (event [Stop_hit]). The exit itself can still
          be withheld by the strategy runner (e.g. the entry-bar skip) — this
          tag records the state machine's decision, not the fill. *)
  | Other_hold
      (** Defensive: a [No_change] step that fits none of the above. Not
          reachable from the current state machine; present so a future state
          change surfaces as a countable tag instead of a mislabel. *)
[@@deriving show, eq, sexp]

(** Which arm of {!Stop_types.stop_state} the stop was in. *)
type state_kind = Initial | Trailing | Tightened [@@deriving show, eq, sexp]

type step = {
  before : Stop_types.stop_state;  (** State passed into the update. *)
  after : Stop_types.stop_state;  (** State the update returned. *)
  event : Stop_types.stop_event;  (** Event the update returned. *)
  bar : Types.Daily_price.t;  (** The bar the update read. *)
  ma_value : float;  (** The MA value the update read. *)
}
(** One [Weinstein_stops.update] call, as seen by its caller. *)

type t = {
  date : Date.t;  (** [step.bar.date]. *)
  position_id : string;
      (** Joins to [Trade_audit.entry_decision.position_id] and [trades.csv]. *)
  state_before : state_kind;
  state_after : state_kind;
  stop_before : float;
  stop_after : float;
  correction_count : int;
      (** Completed cycles on the [Trailing] state after the step (before it, if
          the step left [Trailing]); [0] when neither side is [Trailing]. *)
  last_trend_extreme : float option;
      (** The trend extreme the cycle test measured from. From a [Trailing]
          state: the pre-step running peak (long) / trough (short) — exactly the
          value the correction and recovery tests read. Otherwise the post-step
          state's, when it has one. *)
  last_correction_extreme : float option;
      (** The correction extreme the cycle test read. From a [Trailing] state:
          the running extreme advanced by this bar, before any cycle reset, so
          [(last_trend_extreme - last_correction_extreme) / last_trend_extreme]
          is the depth the [min_correction_pct] gate saw (long). Otherwise the
          post-step state's, when it has one. *)
  ma_value : float;  (** [step.ma_value]. *)
  reason : reason;
}
[@@deriving eq, sexp]
(** One stop decision for one held position. *)

val classify : config:Stop_types.config -> side:position_side -> step -> reason
(** Name the decision the state machine made on [step]. Pure; reads only [step]
    and the correction / recovery thresholds in [config] (via {!Stop_geometry}),
    so it re-derives exactly the test {!Weinstein_stops.update} ran. *)

val make :
  config:Stop_types.config ->
  side:position_side ->
  position_id:string ->
  step ->
  t
(** Build the full record for [step] — see the field docs of {!t}. *)

val is_hold : reason -> bool
(** [true] for the no-move tags a held position emits on most steps
    ([No_correction_yet], [Correction_not_recovered], [Anchor_not_fresh],
    [Tightened_hold], [Other_hold]); [false] for a stop move, a state change, a
    stalled cycle or a hit. Lets a caller sample the frequent holds (e.g. once
    per week) while keeping every rare decision. *)
