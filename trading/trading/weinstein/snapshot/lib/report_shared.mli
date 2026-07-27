(** Text and derived values shared by the two weekly-report renderers.

    {!Report_renderer} (Markdown) and {!Html_report_renderer} (HTML) render the
    same weekly snapshot in two formats. Anything a reader would notice
    differing between the two — the executable order instruction, the risk
    percentage, the footnote prose — is computed here, once, so the formats
    cannot drift. Presentation that is genuinely format-specific (table syntax,
    emphasis, markup) stays in each renderer.

    Both renderers must explain the same three things below a candidate table:

    - a {b fallback stop} — the candidate's [stop] is the fixed
      [entry * initial_stop_buffer] proxy rather than a real structural level
      (issue #2084 Finding 2),
    - a {b data-suspect} candidate — its most recent bar is a single outsized
      move, so the row is flagged but kept (issue #2083 Finding 3),
    - a {b truncated table} — how many candidates were hidden and how many of
      them tie the cutoff score.

    Every string here is returned {b unwrapped} — no Markdown emphasis, no HTML
    tags, no escaping. The caller supplies its own wrapping and, for HTML, its
    own escaping. *)

val risk_pct : entry:float -> stop:float -> float
(** [risk_pct ~entry ~stop] is the percentage of the entry price at risk to the
    stop, [(entry - stop) / entry * 100] (long convention). [0.0] for a zero
    entry price rather than a division by zero. Callers are responsible for the
    sign convention of [entry] / [stop] relative to side. *)

val instruction : Weekly_snapshot.candidate -> string
(** [instruction c] is the executable order for [c], formatted from the
    generator-computed [sized_*] / [sizing_note] fields (fixed-risk sizing,
    mirroring the backtest).

    The ticket shape follows [c.reconciliation] (issue #2103 — see
    {!Entry_reconciliation}):

    - {!Entry_reconciliation.Not_reconciled} /
      {!Entry_reconciliation.Valid_stop} — a resting stop at the entry level,
      e.g.
      ["BUY STOP 55 sh @ $28.49 (~$1567, 1.6% of book, risk $126); on fill place
       SELL STOP @ $26.21, GTC; cancel if unfilled by Friday close"].
    - {!Entry_reconciliation.Through_entry} — a MARKET buy at the current close,
      quoting the overshoot and stating that the size is on the expected fill
      rather than the entry level. A resting stop below the market {e is} a
      market order, so the ticket says so instead of pretending otherwise.
    - {!Entry_reconciliation.Extended} — {b no order at all}: a do-not-chase
      line naming the overshoot, the entry level and the close. This arm takes
      precedence over every [sized_*] fallback below, because an extended
      candidate is deliberately left unsized by {!Trade_sizing}.

    A [0]-share candidate with no note (e.g. a short, which the live strategy
    leaves unsized) renders ["-"]; a [0]-share result {e with} a note renders
    that reason (cash / caps exhausted, invalid stop direction); a
    placeholder-sized candidate prefixes the ["UNSIZED — set portfolio.sexp"]
    note so the size reads as provisional. *)

val close_vs_entry : Weekly_snapshot.candidate -> string
(** Cell text for the "Close vs entry" column: the current close and the
    side-signed overshoot past the entry level, tagged with the class —
    ["$62.00 (+34.5% EXTENDED)"], ["$25.44 (+7.3% through)"],
    ["$135.78 (-3.9%)"]. ["-"] when the candidate is
    {!Entry_reconciliation.Not_reconciled} (mechanism disarmed, or no resident
    bar to price it against). *)

val entry_reconciliation : string
(** Explains the "Close vs entry" column, the ["through"] / ["EXTENDED"] tags
    and why an extended row carries no order. Rendered below a candidate table
    iff {!any_reconciled} holds for the shown rows. *)

val any_reconciled : Weekly_snapshot.candidate list -> bool
(** [any_reconciled shown] is [true] when at least one {e displayed} candidate
    is {!Entry_reconciliation.Through_entry} or {!Entry_reconciliation.Extended}
    — i.e. when the reconciliation actually changed a ticket. A table of
    valid-stop (or unreconciled) rows needs no legend. Gates
    {!entry_reconciliation}. *)

val stop_fallback : string
(** Explains the trailing [*] marker on a non-structural (fixed-buffer) stop
    cell. Rendered below a candidate table iff {!any_fallback_stop} holds for
    the shown rows. *)

val data_suspect : string
(** Explains the trailing ["(!)"] marker on a spike-flagged candidate's symbol
    cell, including that the candidate was {e kept}, not dropped. Rendered below
    a candidate table iff {!any_data_suspect} holds for the shown rows. *)

val any_fallback_stop : Weekly_snapshot.candidate list -> bool
(** [any_fallback_stop shown] is [true] when at least one of the {e displayed}
    candidates carries [stop_is_structural = false]. Gates {!stop_fallback}. *)

val any_data_suspect : Weekly_snapshot.candidate list -> bool
(** [any_data_suspect shown] is [true] when at least one of the {e displayed}
    candidates carries [data_suspect = true]. Gates {!data_suspect}. *)

val truncation :
  shown:Weekly_snapshot.candidate list ->
  hidden:Weekly_snapshot.candidate list ->
  string option
(** [truncation ~shown ~hidden] is the tie-honesty note for a display-capped
    candidate table, or [None] when [hidden] is empty (nothing was cut).

    Candidates arrive score-descending with an alphabetical tie-break. When no
    hidden candidate ties the cutoff (the score of the last shown row), the note
    is a plain ["N lower-scored candidate(s) not shown."]. When some do tie, the
    note reports the tie count and the cutoff score and says explicitly that the
    cut is arbitrary among equals — so a reader funding a book-sized subset
    treats the tied set as interchangeable rather than trusting the alphabetical
    order as a quality ranking.

    Requires [shown] to be non-empty whenever [hidden] is non-empty (a truncated
    table has rows); raises otherwise. *)
