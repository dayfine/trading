(** Build a fixture universe from the symbols a window actually screened.

    {1 Why this exists}

    Every strategy mechanism today goes from a unit test straight to a
    multi-hour ladder run, with nothing in between. The unit tests are correct
    and comprehensive and still cannot catch a 3x candidate explosion — F5 is
    the proof (3,145 trades against a 1,136 baseline, holding period 47.8d ->
    8.4d, return -47.6%, all invisible to its unit tests).

    The blocker for a middle tier has been runtime: a scenario over a real
    universe costs minutes-to-hours, so per-mechanism scenarios are
    unaffordable. But most of that cost is symbols the window never screens.
    This module derives the *small* universe mechanically rather than by
    guesswork: run the window once with the all-eligible diagnostic, collect
    every symbol that ever became a candidate, and pin exactly those.

    {1 The soundness argument}

    Dropping a symbol that never became a candidate cannot change the run,
    because candidate selection is what consumes the universe. The one
    precondition that makes this true: the capture must be taken at the
    {b lowest} gate ([min_grade = F]), so it is the superset of every symbol any
    variant could screen, not just those the default config admitted.

    That precondition is not enforceable from inside this module — it cannot see
    the run. The fixture is therefore a {b hypothesis} until validated by
    re-running the window against it and diffing the trade list.

    {2 What the universe file does and does not control}

    ⚠ A universe file governs {b candidate membership only}. In this codebase
    the macro gate and sector relative-strength read their instruments from a
    separate path, not from the scenario universe: [universes/small.sexp] is 302
    equities with zero ETFs and zero index symbols, and the macro gate works
    fine against it. When a scenario {e does} want the ETFs as members there is
    a purpose-built file for it ([universes/spdr-sectors-11-plus-spy.sexp]).

    So {!required_context_symbols} is {b opt-in}, not automatic. An earlier
    draft of this module unioned it in by default, on the reasoning that the
    gates would otherwise degrade. That reasoning was wrong for this codebase,
    and the effect is the opposite of harmless: it injects 13 tradeable ETFs the
    source universe never had, each of which can become a candidate and change
    the very trade list the fixture is supposed to reproduce. Caught by the
    acceptance run on 2026-08-13, before any fixture shipped. *)

open Core

(** {1 Reading an all-eligible capture} *)

val symbols_of_all_eligible_csv : contents:string -> String.Set.t
(** [symbols_of_all_eligible_csv ~contents] extracts the distinct [symbol]
    column from an all-eligible [trades.csv].

    The header is required and is located by name rather than by position, so a
    column insertion upstream cannot silently shift which field is read. Blank
    lines are skipped; a row with fewer fields than the header is skipped rather
    than raising, matching {!Sector_map.load}'s tolerance for malformed rows.

    Returns the empty set for a header-only file. Raises [Failure] if the header
    has no [symbol] column, since that means the input is not an all-eligible
    capture and every downstream number would be silently wrong. *)

(** {1 Building the universe} *)

val required_context_symbols : string list
(** The macro index and the sector ETFs.

    ⚠ {b Not} added by default — see the header. Include these only when
    reproducing a scenario whose {e own} universe file lists them as members
    (e.g. one built on [universes/spdr-sectors-11-plus-spy.sexp]). Adding them
    to a fixture derived from an equities-only universe changes the run, because
    ETFs are tradeable and can become candidates. *)

val build :
  ?include_context:bool ->
  candidate_symbols:String.Set.t ->
  sector_of:(string -> string option) ->
  default_sector:string ->
  unit ->
  Scenario_lib.Universe_file.pinned_entry list
(** [build ~candidate_symbols ~sector_of ~default_sector ()] returns the pinned
    entries for [candidate_symbols], sorted by symbol so the emitted fixture is
    stable across runs (a fixture that reorders on every build produces noise
    diffs and cannot be reviewed).

    [?include_context] (default [false]) additionally unions
    {!required_context_symbols}. Leave it off unless the source universe itself
    contains those instruments.

    [sector_of] is consulted per symbol; [default_sector] is used where it
    returns [None]. A missing sector is not an error here because the context
    ETFs are frequently absent from [data/sectors.csv], but callers that care
    should report the count — see {!unresolved_sectors}. *)

val sector_of_universe : Scenario_lib.Universe_file.t -> string -> string option
(** Sector lookup backed by a pinned universe file.

    This is the {b authoritative} source for a capture-derived subset, and
    should be preferred over [data/sectors.csv]: the source universe is what the
    full run itself used, so inheriting from it guarantees the fixture's sector
    assignments are identical to the run being reproduced. Consulting
    [sectors.csv] instead can silently disagree — observed 2026-08-13, where a
    302-symbol fixture resolved 297 of 304 symbols to the fallback because the
    local [sectors.csv] is a stub, which would have collapsed every symbol into
    one sector and disabled the sector filter in the fixture run.

    Returns [None] for every symbol when given [Full_sector_map], which carries
    no per-symbol sectors. *)

val first_available : (string -> string option) list -> string -> string option
(** [first_available lookups sym] tries each lookup in order and returns the
    first [Some]. Used to prefer the source universe over [sectors.csv] while
    still covering symbols the source universe lacks (typically the context
    ETFs). *)

val unresolved_sectors :
  ?include_context:bool ->
  candidate_symbols:String.Set.t ->
  sector_of:(string -> string option) ->
  unit ->
  string list
(** Symbols for which [sector_of] returned [None], sorted. Exposed so the caller
    can print them: a large count means the sector map does not cover the
    captured universe, which would make the fixture's sector filter behave
    differently from the full run. *)

(** {1 Emitting} *)

val render :
  entries:Scenario_lib.Universe_file.pinned_entry list ->
  provenance:string list ->
  string
(** [render ~entries ~provenance] is the complete file text: a comment header
    built from [provenance] lines, then the [Universe_file.t] sexp.

    The header is not decoration. A fixture universe is a derived artifact whose
    correctness depends on inputs invisible in the sexp itself (which window,
    which capture, which min-grade), and the 2026-08-13 review of the nearfloor
    cell established that a derived number without its provenance is
    unverifiable in practice. Callers should pass the source capture path, the
    window, the min-grade, and the symbol count. *)
