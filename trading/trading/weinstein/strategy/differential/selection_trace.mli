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
    deterministic text trace. Two builds agree on the selection surface this
    instrument covers iff their traces are byte-identical, so the question
    becomes a [cmp]. It cleared both suspects: 133,512 bytes / md5
    [751a285ddfc70e8b93810a0f37ad5e01] at [bdcb257b], [b128b1d9] and [2b11c60d],
    [cmp] exit 0 on all three pairs.

    "The selection surface this instrument covers" is doing real work in that
    sentence — see the measured coverage below, which names the gates the
    instrument discriminates and the ones it does not.

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

    {2 Which gates actually {e bite} — measured, not asserted}

    "Drives the code" is not "discriminates a change to it". A gate that never
    rejects anything on this fixture cannot tell two builds of itself apart, so
    the covered list above only means something alongside the counts below.
    Measured over the 249 [cascade_diagnostics] records the trace renders (49
    cases + 200 replay rows):

    - macro gate — all three trends, in both the cases and the replay.
    - breakout / price floor / score floor — the 21- and 17-line mutants below.
    - sector gate — rejects in {b 44} records on the long arm, {b 5} on the
      short arm. It rejected in {b zero} until [WEAKB] and [STRGD] were added in
      review of #2507; see their definition in [selection_trace.ml].
    - RS hard gate (short) — 4 replay days.
    - grade admission — 9 cases.
    - top-N truncation — the 18-case cap sweep, cutting inside the tie group.
    - cooldown — 3 boundary cases.
    - point-in-time membership — {b 2} cases arm [?membership_at]; every other
      case leaves it unsupplied, as the production default does.
    - failed-breakout gate — {b never}: [long_failed_breakout_dropped] is 0 in
      all 249 records. Not covered.

    {1 What it deliberately does not cover}

    The scenario/backtest driver ({!Backtest.Runner}) and anything requiring a
    bar warehouse. This is a synthetic in-process instrument; it cannot speak to
    data-layer or fill-model behaviour. A trace match is evidence about the
    selection surface only — see [.claude/rules/mechanism-validation-rigor.md]
    on calibrating a proxy's verdict to what it actually measures.

    Four further limits, stated rather than papered over:

    - The replay's per-week rows carry the full cascade funnel but
      {b no entries} — the walk admits candidates and funds none under this
      fixture's sizing. So the replay discriminates changes to the cascade
      inside [screen_universe]; changes to the entry-walk half are discriminated
      by the standalone {!Weinstein_strategy.entries_from_candidates} cases,
      which do emit entries.
    - {b The replay is far shallower than "200 screening days" reads.} Of the
      200 rows, {b 61} have [total_stocks = 0] (warmup) and {b 196} have
      [long_breakout_admitted = 0] — the long cascade dies at the breakout gate.
      Only {b 4} rows reach ranking / top-N on the long side, and {b zero}
      produce a short candidate at top-N. The upstream gates are exercised on
      all 200 days; a change to ranking, the tiebreak or the cap
      {e as reached through the composed path} is discriminated by 4. The 49
      standalone cases are what discriminate those.
    - {b The replay does not exercise the sector gate at all.} It drives
      {!Weinstein_strategy.on_market_close}, which derives its own sector
      context rather than reading {!sector_map}, and every symbol reads Neutral
      there. The sector counts above come from the standalone cases only.
    - Mutation testing found one surviving mutant: widening the min-price gate's
      {e disable} condition from [min_price <= 0.0] to [< 0.0]. At the default
      [min_price = 0.0] that only changes the fate of candidates with an
      {b unknown} breakout price, and this fixture has none among the admitted
      set. A candidate with [breakout_price = None] would close it.

    {1 Sensitivity — and how to measure it without fooling yourself}

    A trace that never moves proves nothing unless it can move. Mutating the
    screener and re-rendering, against the unmutated 893-line trace:

    {v
    mutation                                   built?  moved  suite
    sector gate deleted (both arms)            yes     94     red
    membership gate neutered (always admit)    yes     12     red
    score floor  >= -> >                       yes     21     red
    price floor  >= -> >                       yes     17     red
    Alphabetical tiebreak reversed             yes     540    red
    top-N cap  n -> n+1                        yes     35     red
    top-N cap  n -> n-1  (guarded at 0)        yes     35     red
    min-price disable  <= 0.0 -> < 0.0         yes     0      GREEN (above)
    v}

    {b Confirm a mutant built AND wrote non-empty output before believing its
       line count.} An unguarded [n - 1] at the cap raises [Invalid_argument] on
    the [cap/max_buy=0] case ([List.sub ~len:(-1)]); the dump then writes
    {b zero bytes}, and [diff] reports every baseline line as removed — a number
    exactly equal to the trace's total line count, which reads as a maximal
    diff. #2507 originally published {b 834} for this mutation on the pre-review
    fixture for precisely that reason, and 834 was that fixture's line count.
    The real figure is {b 35}, in both directions. Only a mutant that ran to
    completion can produce a {e partial} diff, so a count strictly between 0 and
    the total is safe by construction; a count equal to the total is the
    artefact's signature. *)

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
(** Ticker to sector context. Groups carry distinct ratings, and
    {!weak_sector_long} / {!strong_sector_short} give each arm of the gate a
    symbol it actually rejects — without which the gate is inert and a change to
    it is invisible. Consumed by
    {!Screener.screen}[/]{!Screener.screen_with_cooldown} only: the replay path
    derives its own sector context and never reads this map. *)

val weak_sector_long : string
(** A Stage-2 breakout in a {b Weak} sector: shape-identical to a {!tie_group}
    member, so the sector rating is the only thing separating it from admission.
    The long arm of the sector gate must reject it. *)

val strong_sector_short : string
(** A Stage-4 decliner in a {b Strong} sector — the short-arm mirror of
    {!weak_sector_long}. The short arm of the sector gate must reject it. *)

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
