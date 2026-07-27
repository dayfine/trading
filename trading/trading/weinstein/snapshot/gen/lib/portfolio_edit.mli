(** Pure edits to a {!Live_portfolio.t} — the book-keeping behind the
    [record_fill] CLI (weekly-snapshot item 4c.a).

    The point of these functions is that [cash] can never drift out of step with
    the position list: every share movement debits or credits cash in the same
    operation, so there is no way to record a fill and forget the money. All
    three are pure — they take a portfolio and return a new one, and the caller
    does the file I/O ({!Live_portfolio.load} / {!Live_portfolio.save}).

    {1 Three operations, not one signed delta}

    - {!record} opens a brand-new position (cash out).
    - {!close} fully exits one (cash in) and is the {b only} function that
      removes a symbol from the book.
    - {!adjust} changes the stop and/or trims part of a holding, and never fully
      closes it.

    Each carries one invariant that the other two do not (must not already be
    held / must be held / must stay open), so keeping them separate makes each
    invariant a single named check with a single named test, instead of three
    branches of one signed-delta function.

    {1 Symbol case}

    Symbols are normalised to uppercase on the way in, for both storage and
    lookup, so [aapl] and [AAPL] are the same holding. A ticker recorded
    lower-case is therefore stored upper-case.

    {1 [as_of] is an argument, never the wall clock}

    Every function takes the new [as_of] date explicitly. Reading [Date.today]
    here would make the result depend on hidden state and stop the functions
    being reproducibly testable; the CLI asks the user for [--as-of] instead. *)

open Core

type trim = {
  shares : int;  (** Shares sold; must be positive and less than shares held. *)
  price : float;  (** Fill price of the partial sale; must be positive. *)
}
[@@deriving sexp, eq, show]
(** A partial sale out of an existing position. The two fields travel together
    as one value so "shares without a price" is unrepresentable rather than a
    runtime check. *)

val record :
  Live_portfolio.t ->
  as_of:Date.t ->
  position:Live_portfolio.position ->
  Live_portfolio.t Or_error.t
(** [record t ~as_of ~position] appends [position] (symbol upper-cased) and
    debits [shares * entry_price] from cash.

    Errors when:
    - the symbol is already held — recording the same fill twice cannot silently
      double a position; use {!adjust}, or {!close} first. This is deliberately
      not a weighted-average merge: the schema carries one row and one
      [entry_price] per symbol, so scale-in has nowhere to live;
    - [shares], [entry_price] or [stop_price] is not positive, or the symbol is
      blank;
    - [stop_price >= entry_price] — Weinstein's initial stop sits below the
      entry (docs/design/weinstein-book-reference.md §5.1);
    - the debit would take cash negative. *)

val close :
  Live_portfolio.t ->
  as_of:Date.t ->
  symbol:string ->
  exit_price:float ->
  Live_portfolio.t Or_error.t
(** [close t ~as_of ~symbol ~exit_price] removes the holding and credits
    [shares_held * exit_price] to cash.

    Errors when the symbol is not held (so a repeated [close] reports "not held"
    rather than crediting the proceeds twice) or [exit_price] is not positive.
*)

val adjust :
  Live_portfolio.t ->
  as_of:Date.t ->
  symbol:string ->
  ?stop_price:float ->
  ?allow_lower:bool ->
  ?trim:trim ->
  unit ->
  Live_portfolio.t Or_error.t
(** [adjust t ~as_of ~symbol ?stop_price ?allow_lower ?trim ()] updates an open
    position in place, leaving it open.

    - [?stop_price] sets the working stop; no cash moves. Unlike {!record} this
      does {b not} require the stop to sit below [entry_price]: a trailing stop
      legitimately rises past the entry once the position is in profit.
    - [?trim] sells part of the holding, crediting [shares * price] to cash and
      reducing the position's share count.

    {1 The never-lower rule (weekly-snapshot item 4c.b)}

    A stop {b strictly below} the one in force is {b rejected}. Weinstein's
    trailing stop moves up as the MA advances and is never moved against the
    position (weinstein-book-reference.md §5.2 "Trailing Stop — Investor
    Method"); lowering one converts a defined loss into an open-ended one, which
    is §5.4's "don't hold hoping it will come back" mechanised. Setting the
    {e same} stop is allowed, so re-running a command is idempotent.

    [?allow_lower] (default [false], CLI [--allow-lower-stop]) overrides the
    refusal. It exists for the one legitimate case — correcting a mistyped stop,
    where a permanent one-way ratchet on a typo would be worse than the rule it
    enforces — and so must be passed deliberately; the refusal message names it.

    [stop_state] is kept in step with the edit, so a later
    {!Stop_thread.advance} cannot resurrect a level the trader has moved past:
    - a raise ratchets the carried track up to the new stop
      ({!Stop_track.ratchet}), preserving its state arm and correction
      bookkeeping. If the track's own level already sits higher, it is left
      alone — that is the never-lower rule applied to the track itself.
    - an [allow_lower] lowering {b clears} the track ([None]). The machine's
      accumulated state no longer describes a position whose stop has been moved
      against it, so the holding falls back to the stateless recomputed floor
      ({!Stop_recompute.for_held_long}) the report used before item 4c.b.
    - [?trim] does not touch the track: a share count is not stop state.

    {b Clearing is a one-way trapdoor today.} {!Stop_thread.seed} can derive a
    fresh track from bars, but it has no production caller and nothing writes
    [portfolio.sexp] back (both are item 4c.c), so no later run recreates a
    cleared track — the ratchet history is gone until someone writes a
    [stop_state] into the file by hand. The working stop itself is unaffected
    and the report stays correct, only stateless. Worth knowing before reaching
    for [--allow-lower-stop] on a long-held position.

    Errors when the symbol is not held, when neither [stop_price] nor [trim] is
    supplied (a no-op edit is a mistake worth reporting), when [stop_price] is
    not positive or is lowered without [allow_lower], or when
    [trim.shares >= shares_held] — a full exit goes through {!close}, so exactly
    one function can zero a holding. *)
