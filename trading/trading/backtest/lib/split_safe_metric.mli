(** The {e inert fraction} of a [split_safe_floors] arm, reduced from a
    population of {!Trade_audit.split_safe_basis} tags.

    [stops_config.split_safe_floors]'s whole-window fallback is silent in the
    answer it produces — it returns exactly the flag-off level (see
    {!Weinstein_stops.split_safe_basis}) — so a walk-forward arm over
    [((stops_config ((split_safe_floors true))))] can be substantially inert
    with no signal other than "on == off" in aggregate. The per-decision tag
    recorded on every [Trade_audit.entry_decision] restores the signal. This
    module is the one place that turns a column of those tags into the number,
    so a reader counting by hand and a rendered report cannot disagree about how
    it is computed.

    {b Not a renderer.} Nothing here formats anything. The trade-audit report
    row that will consume this is follow-up F6 in
    [dev/status/support-floor-stops.md] §Follow-ups. *)

type tally = {
  flag_off : int;
  adjusted : int;
  raw_fallback : int;
  empty_window : int;
}
[@@deriving show, eq, sexp]
(** How many decisions in a population landed in each basis state. *)

val empty_tally : tally
(** All four counts zero — the tally of an empty population. *)

val tally_of_bases : Trade_audit.split_safe_basis list -> tally
(** [tally_of_bases bases] counts each state. Order-independent and total: every
    constructor is counted, none is dropped. *)

(** The inert fraction of a population, in a shape that cannot render as a
    blank.

    The metric is [raw_fallback / (raw_fallback + adjusted)]. [Empty_window] and
    [Flag_off] are excluded from {b both} terms, and the exclusion is not
    symmetric bookkeeping — each is excluded for its own reason. A window with
    no bars was never given a chance to act, so it is a non-event rather than a
    degradation; a [Flag_off] row inside an arm configured
    [split_safe_floors true] means the flag never reached the scan at all, which
    is a fact about the harness, not about the mechanism. Folding either into
    the numerator would overstate inertness; folding either into the denominator
    would understate it.

    {b Why this is a variant and not a [float].} That denominator can be zero,
    and a bare [0/0] — rendered as an empty cell, or worse as [nan] or as [0.0]
    — is indistinguishable from "this column was never wired up". The two states
    call for opposite responses: disqualify the arm for lack of exposure, versus
    stop and go fix the harness. Naming the undefined case forces every consumer
    to tell them apart at the point where it would otherwise print a blank. *)
type inertness =
  | Inert_fraction of float
      (** [raw_fallback / (raw_fallback + adjusted)], in \[0., 1.\]. At least
          one decision reached the basis choice, so the population carries
          evidence about the mechanism: [0.] means every such decision ran on
          the adjusted basis, [1.] means every one degraded to raw and the arm
          measured baseline while appearing to test the flag. *)
  | Not_exercised of tally
      (** The denominator is zero: no decision reached the basis choice, so the
          population says {b nothing} about [split_safe_floors] and must not be
          read as "0% inert". The tally is carried so the reason stays legible
          at the site that would otherwise print a blank:

          - [flag_off > 0] — decisions exist but the flag never reached the
            scan. In an arm configured [split_safe_floors true] that is a
            {b wiring alarm}, not a data point.
          - [empty_window > 0] with [flag_off = 0] — the flag did reach the
            scan, but every window was empty (no bars in the lookback). The
            mechanism ran and had nothing to act on: the arm lacks exposure.
          - every count zero — the population itself is empty (e.g. a run that
            entered no positions), so there is nothing to say either way. *)
[@@deriving show, eq]

val inertness_of_tally : tally -> inertness
(** [inertness_of_tally tally] is the metric described on {!inertness}. Pure;
    total. *)
