(** Entry-reconciliation pass over screener candidates (issue #2103).

    Reads each candidate's current close from the bar reader and stamps the
    {!Weinstein_snapshot.Weekly_snapshot.candidate.reconciliation} field with
    the class {!Weinstein_snapshot.Entry_reconciliation.classify} computes — see
    that module for the classification, its thresholds and its Weinstein
    authority.

    {b Run this before sizing.} The class decides
    {!Weinstein_snapshot.Weekly_snapshot.expected_fill_price}, and
    {!Trade_sizing} sizes on that price; running it afterwards would leave the
    stale-breakout-level sizing issue #2103 is about. The generator wires it
    between the structural-stop overlay ({!Stop_recompute}) and the sizing pass,
    for {b both} the long and the short candidate lists.

    Shape mirrors {!Stop_recompute}: a per-candidate overlay that returns the
    candidate unchanged when it cannot do better. *)

val for_candidate :
  Weinstein_strategy.Bar_reader.t ->
  as_of:Core.Date.t ->
  side:[ `Long | `Short ] ->
  through_band_pct:float ->
  extension_max_pct:float ->
  Weinstein_snapshot.Weekly_snapshot.candidate ->
  Weinstein_snapshot.Weekly_snapshot.candidate

(** [for_candidate reader ~as_of ~side ~through_band_pct ~extension_max_pct c]
    is [c] with its [reconciliation] field set from the last resident daily
    close at or before [as_of].

    Returns [c] {b unchanged} (leaving
    {!Weinstein_snapshot.Entry_reconciliation.Not_reconciled}) when the
    mechanism is disarmed ([extension_max_pct <= 0.0], the default) or the
    symbol has no resident bars — a candidate whose price cannot be read is
    reported honestly as un-reconciled rather than assumed valid.

    [side] mirrors the classification for shorts: a short candidate is "through
    its entry" when the close is {e below} the breakdown level. *)

val for_candidates :
  Weinstein_strategy.Bar_reader.t ->
  as_of:Core.Date.t ->
  side:[ `Long | `Short ] ->
  through_band_pct:float ->
  extension_max_pct:float ->
  Weinstein_snapshot.Weekly_snapshot.candidate list ->
  Weinstein_snapshot.Weekly_snapshot.candidate list
(** {!for_candidate} mapped over a ranked candidate list. Order and membership
    are preserved: reconciliation annotates, it never drops a candidate (an
    over-extended name keeps its row for watch purposes). *)
