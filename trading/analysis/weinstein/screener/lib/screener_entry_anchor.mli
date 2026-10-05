(** Ticket-level entry anchor for a screened candidate, first match wins (#3056,
    #3067, #3074, #3131). Factored out of [screener.ml] (file-length cap).

    Longs:
    + the continuation detector's [consolidation_high] — pattern-specific, book
      §4.6 "breaks out anew above the top of its resistance zone"; the old base
      top in [breakout_price] sits below a continuation name's close;
    + [analysis.local_range_top] (the generic local-range knob);
    + [analysis.breakout_price], else the MA-based fallback above the MA.

    Shorts (#3131):
    + [analysis.breakdown_price] (the support floor of the prior base) — book
      Ch. 7: the sell-stop goes at the breakdown below support, not at the top
      of the range;
    + else the MA-based fallback mirrored below the MA.

    Only the entry (and its derived stop / risk) follows the anchor;
    [swing_target], admission and grading still read [breakout_price]. *)

(** Which arm of the rule anchored the ticket. *)
type kind =
  | Continuation
      (** Longs only: the continuation detector's [consolidation_high]. *)
  | Local_range_top  (** Longs only: [analysis.local_range_top]. *)
  | Breakout  (** Longs only: [analysis.breakout_price]. *)
  | Breakdown  (** Shorts only: [analysis.breakdown_price] (#3131). *)
  | Ma_fallback
      (** No base level: the MA-based fallback,
          [ma_value *. (1 +. breakout_fallback_pct)] for a long (no
          [breakout_price]) and [ma_value *. (1 -. breakout_fallback_pct)] for a
          short (no [breakdown_price]). *)
[@@deriving sexp, show, eq]

val choose : is_short:bool -> Stock_analysis.t -> kind * float option
(** [choose ~is_short a] is the arm that fires and, for the [Continuation],
    [Local_range_top] and [Breakdown] arms, the anchor level. It is [None] for
    [Breakout] and [Ma_fallback]: the caller anchors at its own default
    ([breakout_price], else the MA fallback on the candidate's side), which
    needs the candidate parameters this module does not take. The kind and the
    level come from one match, so they cannot disagree. *)
