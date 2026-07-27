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
  ?trim:trim ->
  unit ->
  Live_portfolio.t Or_error.t
(** [adjust t ~as_of ~symbol ?stop_price ?trim ()] updates an open position in
    place, leaving it open.

    - [?stop_price] sets the working stop; no cash moves. Unlike {!record} this
      does {b not} require the stop to sit below [entry_price]: a trailing stop
      legitimately rises past the entry once the position is in profit.
    - [?trim] sells part of the holding, crediting [shares * price] to cash and
      reducing the position's share count.

    Errors when the symbol is not held, when neither argument is supplied (a
    no-op edit is a mistake worth reporting), when [stop_price] is not positive,
    or when [trim.shares >= shares_held] — a full exit goes through {!close}, so
    exactly one function can zero a holding. *)
