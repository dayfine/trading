(** Ticket-level entry anchor for a screened candidate, first match wins (#3056,
    #3067, #3074). Factored out of [screener.ml] (file-length cap).

    + (longs only) the continuation detector's [consolidation_high] —
      pattern-specific, book §4.6 "breaks out anew above the top of its
      resistance zone"; the old base top in [breakout_price] sits below a
      continuation name's close;
    + [analysis.local_range_top] (the generic local-range knob);
    + [analysis.breakout_price], else the MA-based fallback.

    Only the entry (and its derived stop / risk) follows the anchor;
    [swing_target], admission and grading still read [breakout_price]. *)

(** Which arm of the rule anchored the ticket. *)
type kind =
  | Continuation
      (** Longs only: the continuation detector's [consolidation_high]. *)
  | Local_range_top  (** [analysis.local_range_top]. *)
  | Breakout  (** [analysis.breakout_price]. *)
  | Ma_fallback
      (** No [breakout_price]: the MA-based fallback
          ([ma_value *. (1 + breakout_fallback_pct)]). *)
[@@deriving sexp, show, eq]

val choose : is_short:bool -> Stock_analysis.t -> kind * float option
(** [choose ~is_short a] is the arm that fires and, for the [Continuation] and
    [Local_range_top] arms, the anchor level. It is [None] for [Breakout] and
    [Ma_fallback]: the caller anchors at its own breakout default
    ([breakout_price], else the MA fallback), which needs the candidate
    parameters this module does not take. The kind and the level come from one
    match, so they cannot disagree. *)
