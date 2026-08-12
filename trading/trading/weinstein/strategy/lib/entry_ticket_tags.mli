(** Placement-time audit tags for a resting entry ticket.

    Pure projections off the {!Stock_analysis.t} the strategy already holds when
    it builds an entry — no bar walking, no config threading, no new analysis.
    They exist so {!Backtest.Trade_audit}'s per-entry row can answer the
    ladder-v4 questions the plan
    ([dev/plans/entry-ticket-async-v2-2026-08-10.md] §4 PR-5, §5) poses about
    the ticket lifecycle:

    - {b which clock admitted this candidate} ({!freshness_basis_of_analysis},
      F1); and
    - {b was this a §4.5 triple-confirmation name}
      ({!triple_confirmation_of_analysis}, F6).

    {b Capture only.} Nothing here gates, scores, or sizes anything. F6 is
    explicitly an audit feature and {b not} a gate (plan §3-F6): v4 reads the
    captured tag to ask "does the triple-confirmed cohort contain the
    monsters?"; only a later plan may promote it to a filter. *)

type triple_confirmation = {
  breakout_volume_multiple : float option;
      (** §4.5 (1) "volume explosion" — the breakout bar's volume over its
          prior-weeks average ([Volume.result.volume_ratio]). [None] when no
          breakout volume event could be classified for this analysis. *)
  rs_zero_cross : bool;
      (** §4.5 (2) "RS breakout" — the RS line moved from near the zero line
          into positive territory on the breakout, i.e. the classified trend is
          [Weinstein_types.Bullish_crossover] (the book's own "A+ bonus" state).
          [false] when the analysis carried no RS result — absence of evidence,
          recorded as "not observed". *)
  in_base_advance_pct : float option;
      (** §4.5 (3) "pre-breakout advance" — how far the stock advanced
          {i inside} its base before breaking out, as
          [(breakout_price - breakdown_price) / breakdown_price]: the base's top
          over the base's floor, both already computed on the same prior-base
          window. [None] when either level is undefined or the floor is
          non-positive. Book reference level: {!book_min_in_base_advance_pct}.
      *)
}
[@@deriving show, eq]
(** The three §4.5 "big winner" signals, captured as measurements rather than a
    verdict ([docs/design/weinstein-book-reference.md] §4.5). Recorded on every
    placed ticket. *)

val book_min_in_base_advance_pct : float
(** [0.40] — §4.5's "pre-breakout advance ≥ 40%" reference level (National
    Semiconductor, Blocker Energy: the accumulation signature). A documented
    constant, not a threshold this module applies on its own behalf: only
    {!is_triple_confirmed} reads it, and nothing in the strategy calls that. *)

val triple_confirmation_of_analysis : Stock_analysis.t -> triple_confirmation
(** Project the three §4.5 signals out of a candidate's analysis. Total — every
    unavailable input becomes [None] / [false] rather than an exception, so a
    thin-history candidate still produces a row. *)

val is_triple_confirmed :
  strong_volume_threshold:float -> triple_confirmation -> bool
(** All three §4.5 signals present: the volume multiple reaches
    [strong_volume_threshold] (pass [Volume.config.strong_threshold] — the same
    2× the screen-time grade uses, so the cohort definition cannot drift from
    the configured grade), the RS zero-cross fired, and the in-base advance
    reaches {!book_min_in_base_advance_pct}. A missing measurement is not a
    confirmation, so [None] fails.

    Provided for cohort analysis of a completed run ([trade_audit.sexp]
    consumers, tests). {b No strategy code calls this} — F6 gates nothing. *)

val freshness_basis_of_analysis : Stock_analysis.t -> Entry_freshness.basis
(** Which F1 admission clock was in force when this candidate was analysed.

    Read off {!Stock_analysis.t.range_top_freshness}, whose contract is that it
    is [None] {i exactly} under the default [Ma_cross] basis and [Some _]
    (including [Some false]) under [Range_top_breakout] — see
    {!Entry_freshness.range_top_freshness}. {!Stock_analysis.analyze} populates
    it unconditionally from [config.entry_freshness_basis], so this recovers the
    configured basis rather than guessing at it. *)
