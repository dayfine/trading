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
    holding still renders a sensible row rather than vanishing. Pure with
    respect to [bar_reader] (read-only).

    {1 Two stop views, decided by [position.stop_state] (item 4c.b)}

    - [None] — the pre-4c.b path, unchanged: [status] is ["Holding"] and
      [recommended_stop] is a support floor recomputed fresh from this week's
      bars ({!Stop_recompute.for_held_long}). Every [portfolio.sexp] written
      before item 4c.b takes this branch, so an un-threaded book renders exactly
      as it did before.
    - [Some prior] — the threaded path: the carried state is advanced through
      the weeks since it was last updated ({!Stop_thread.advance}).
      [recommended_stop] is the state machine's stop {e in force}, and [status]
      is {!Stop_track.label} — the state arm plus the number of times the stop
      has ratcheted, which is the history a per-week recomputation cannot
      express. A weekly close through the stop instead reports
      ["STOP HIT <date> (weekly close below $<level>)"].

    No snapshot-schema field is added for this: [status] is already a free-form
    string both renderers print, so the machine's description reaches the report
    without a [current_schema_version] bump. *)

val enrich_all :
  Weinstein_strategy.Bar_reader.t ->
  config:Weinstein_strategy.config ->
  as_of:Date.t ->
  Live_portfolio.position list ->
  Weinstein_snapshot.Weekly_snapshot.held_position list * string list
(** [enrich_all bar_reader ~config ~as_of positions] maps {!enrich} over the
    held book and pairs the rows with their tickers — the two views the
    generator threads to the screener (held tickers) and the report (rows).
    Lives here rather than in the generator to keep that coordinator within the
    file-length limit; pure convenience over {!enrich}. *)

val long_market_value :
  Weinstein_snapshot.Weekly_snapshot.held_position list -> float
(** [long_market_value held] is the sum of [shares * current_price] over [held]
    — the long market value of the held book at run-date prices, which the
    generator adds to cash to get the portfolio value it sizes against. *)
