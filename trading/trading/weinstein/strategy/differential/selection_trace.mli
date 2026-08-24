(** Deterministic selection-path trace — a differential instrument for refactors
    of the screener / admission / entry-walk surface.

    {1 Why this exists}

    Issue #2503 reported that a verbatim config clone of a committed baseline
    spec diverged on [main] from the first weeks of the run — different symbols
    entered from day one. "Different symbols, from day one" localises to the
    {b selection} path, and the suspects were two PRs (#2500, #2501) framed as
    pure instrumentation ("emit candidates", "trace the cascade").

    Instrumentation is only observational if it is provably inert when off.
    Reading a diff can suggest that; it cannot establish it, because the ways an
    admission refactor breaks are exactly the ways a diff reads as harmless — a
    [>=] that became a [>], a tie-break that reordered, a top-N truncation that
    now cuts one element earlier, a float association that shifted a score by
    one ulp.

    This module renders the observable output of the selection path as a
    deterministic text trace. Two builds are identical on the default selection
    path iff their traces are byte-identical, so the question becomes a [cmp].

    {1 What it covers}

    - {!Screener.screen} and {!Screener.screen_with_cooldown} — macro gate,
      breakout / sector / RS / grade admission, ranking, top-N truncation, the
      cooldown and point-in-time membership gates, and the cascade diagnostics
      counters.
    - {!Weinstein_strategy.entries_from_candidates} — the entry walk, whose
      emitted transitions are the actual selection outcome.
    - {!Weinstein_strategy.on_market_close}, replayed week by week over a
      synthetic daily series. This is the {e composed} path — the one that
      reaches [screen_universe], the single function both #2500 and #2501
      edited. Without it the differential would measure the parts and leave the
      composition unmeasured.

    {1 What it deliberately does not cover}

    The scenario/backtest driver ({!Backtest.Runner}) and anything requiring a
    bar warehouse. This is a synthetic in-process instrument; it cannot speak to
    data-layer or fill-model behaviour. A trace match is evidence about the
    selection surface only — see [.claude/rules/mechanism-validation-rigor.md]
    on calibrating a proxy's verdict to what it actually measures.

    Two further limits, stated rather than papered over:

    - The replay's per-week rows carry the full cascade funnel but
      {b no entries} — the walk admits candidates and funds none under this
      fixture's sizing. So the replay discriminates changes to the cascade
      inside [screen_universe]; changes to the entry-walk half are discriminated
      by the standalone {!Weinstein_strategy.entries_from_candidates} cases,
      which do emit entries.
    - Mutation testing found one surviving mutant: widening the min-price gate's
      {e disable} condition from [min_price <= 0.0] to [< 0.0]. At the default
      [min_price = 0.0] that only changes the fate of candidates with an
      {b unknown} breakout price, and this fixture has none among the admitted
      set. A candidate with [breakout_price = None] would close it. *)

(** {1 The fixture}

    Exposed so the regression suite pins the same universe the differential
    walked, rather than a parallel one that could drift away from it. *)

val as_of : Core.Date.t
(** The screening date every case is evaluated at. *)

val stocks : Stock_analysis.t list
(** The synthetic universe, in feed order — deliberately {b not} alphabetical,
    so "the order the screener emitted" cannot be confused with "the order they
    were fed in". *)

val universe_tickers : string list
(** Tickers of {!stocks}, in the same order. *)

val sector_map : unit -> (string, Screener.sector_context) Core.Hashtbl.t
(** Ticker to sector context. Groups carry distinct ratings so each arm of the
    sector gate (Weak blocks longs, Strong blocks shorts) is exercised. *)

val tie_group : string list
(** The five tickers built from a verbatim-identical price/volume series, so
    their scores are exactly equal and only the ticker distinguishes them. In
    ascending alphabetical order — i.e. the order the default [Alphabetical]
    tiebreak must emit them in, whatever order they were fed. *)

val case_count : int
(** Number of distinct (universe x config) selection cases the trace exercises.
    Reported alongside a [cmp] result so an exoneration claim carries its own
    sample size rather than an unquantified "the traces matched". *)

val render : unit -> string
(** [render ()] runs every case and returns the full trace.

    Deterministic and self-contained: no clock, no filesystem, no environment,
    no hashtable-iteration order in the output (every emitted collection is
    either in the order the code under test produced it — which is precisely
    what we are testing — or explicitly sorted). Calling it twice in one process
    yields equal strings, and so does calling it in two processes.

    The trace records, per case: the ordered buy and short candidate lists with
    each candidate's ticker, score and grade; the cascade-diagnostics phase
    counters; and the ordered entry-walk transitions. Order is load-bearing
    throughout — a reordering is a behaviour change, and rendering the list in
    emitted order is what lets [cmp] see it. *)
