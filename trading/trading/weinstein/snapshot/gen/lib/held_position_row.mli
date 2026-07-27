(** Held-position enrichment for {!Weekly_snapshot_generator}.

    Turns a human-edited {!Live_portfolio.position} into the report-ready
    {!Weinstein_snapshot.Weekly_snapshot.held_position} row the weekly report
    renders: priced at the run date, with its unrealized return and this week's
    recomputed Weinstein stop.

    Extracted verbatim out of [weekly_snapshot_generator.ml] (no behaviour
    change) — the generator was at the 300-line file-length limit and this block
    is self-contained: it concerns the {e held} book, not the screener cascade.
    Reimplements no stop logic; {!Stop_recompute.for_held_long} does that. *)

open Core

val enrich :
  Weinstein_strategy.Bar_reader.t ->
  config:Weinstein_strategy.config ->
  as_of:Date.t ->
  Live_portfolio.position ->
  Weinstein_snapshot.Weekly_snapshot.held_position
(** [enrich bar_reader ~config ~as_of position] prices [position] at [as_of]
    (the last daily bar's close) and returns its report row.

    Graceful degradation for a symbol with no resident daily bars:
    [current_price] falls back to the position's [entry_price] (so
    [unrealized_pct = 0.0]) and [recommended_stop] is [None] — an un-priced
    holding still renders a sensible row rather than vanishing. [status] is
    always ["Holding"]; the full trailing stop state machine is not threaded
    here (deferred to Phase C). Pure with respect to [bar_reader] (read-only).
*)

val long_market_value :
  Weinstein_snapshot.Weekly_snapshot.held_position list -> float
(** [long_market_value held] is the sum of [shares * current_price] over [held]
    — the long market value of the held book at run-date prices, which the
    generator adds to cash to get the portfolio value it sizes against. *)
