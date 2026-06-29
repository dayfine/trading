(** Candidate-ranking tiebreak for the Weinstein cascade screener.

    Extracted from [Screener] to keep the cascade coordinator within the
    declared-large file-length limit. Owns the {!candidate_ranking} mode and the
    total order the screener uses to sort and cap candidates. Callers outside
    the screener library reference these through {!Screener}, which re-exports
    this module via [include].

    All functions are pure. *)

(** How equal-score candidates are ordered at the cap (and, downstream, at the
    cash boundary). The {e primary} sort is always [score] descending; this
    governs only the tiebreak among candidates with {e identical} scores.

    - [Alphabetical]: break ties by [String.compare ticker] — the historical
      behaviour.
    - [Quality]: break ties by a continuous Weinstein-faithful key — RS
      magnitude ([rs.current_normalized]) descending, then earliness
      ([weeks_advancing]) ascending, then volume-expansion ([volume_ratio])
      descending, with alphabetical ([ticker]) as the final deterministic
      fallback (required for reproducible backtests).

    RS-for-selection is a Weinstein spine item; avoiding an extended Stage 2 is
    book-sanctioned (weinstein-book-reference.md §Relative Strength, §Stage 2:
    Advancing). [Quality] does {e not} change the additive score itself. *)
type candidate_ranking = Alphabetical | Quality [@@deriving sexp, eq]

type rankable = {
  score : int;  (** Primary sort key — additive cascade score. *)
  ticker : string;  (** Final deterministic tiebreak key. *)
  analysis : Stock_analysis.t;
      (** Source of the [Quality] tiebreak keys (RS, [weeks_advancing], volume).
      *)
}
(** The minimal projection of a scored candidate the ranking needs. [Screener]
    adapts its [scored_candidate] to this so the comparator does not depend on
    the full record. *)

val compare_rankable : candidate_ranking -> rankable -> rankable -> int
(** [compare_rankable ranking a b] is the total order the cascade sorts and caps
    by: primary key [score] descending, then the [ranking] tiebreak among equal
    scores (see {!candidate_ranking}). Pure. *)
