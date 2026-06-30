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
    - [Quality_earliness]: the same keys as [Quality] but with
      {b earliness primary} — [weeks_advancing] ascending leads (prefer the
      freshest Stage-2 breakout), then RS magnitude descending, then volume
      ratio descending, then ticker. The more faithful reading of "do not buy an
      extended Stage 2": among ties it picks the earliest setup rather than the
      highest-RS (= most extended) one. [Quality] (RS-primary) was rejected by
      the 2026-06-29 breadth grid for tilting toward extended names; this is its
      forward-directive successor.

    RS-for-selection is a Weinstein spine item; avoiding an extended Stage 2 is
    book-sanctioned (weinstein-book-reference.md §Relative Strength, §Stage 2:
    Advancing). Neither [Quality] nor [Quality_earliness] changes the additive
    score itself; both reorder only among {e identical-score} candidates.

    {b Diagnostic control modes} — [Reverse_alphabetical], [Symbol_length],
    [Hash_order] — are deliberately {e uninformative} tiebreaks (NOT for default
    use). They bracket the {e noise floor} of the equal-score tiebreak: if every
    uninformative sort performs alike and the informative modes sit inside that
    band, no sort beats unbiased sampling (project_edge_is_the_fat_tail).
    [Hash_order] is a deterministic cross-platform FNV-1a order (a reproducible
    proxy for a random shuffle); all three fall back to [ticker] for
    reproducibility. *)
type candidate_ranking =
  | Alphabetical
  | Quality
  | Quality_earliness
  | Reverse_alphabetical
  | Symbol_length
  | Hash_order
[@@deriving sexp, eq]

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
