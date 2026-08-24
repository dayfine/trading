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

    - {!Entry_reconciliation.Not_reconciled} — a plain resting stop at the entry
      level (no cap carried), e.g.
      ["BUY STOP 55 sh @ $28.49 (~$1567, 1.6% of book, risk $126); on fill place
       SELL STOP @ $26.21, GTC; cancel if unfilled by Friday close"]. This is
      the exact pre-#2158 wording, so a disarmed / legacy row renders unchanged.
    - {!Entry_reconciliation.Valid_stop} — a resting {b stop-limit}: the order
      triggers at the entry and fills anywhere up to the do-not-chase cap, e.g.
      ["BUY STOPLIMIT 55 sh, trigger $28.49 limit $30.05 (~$1651, 1.6% of book,
       worst-case risk $198); on fill place SELL STOP @ $26.21, GTC; cancel if
       unfilled by Friday close"]. The risk is the {b worst case} (sized on the
      cap — issue #2158, "size on the cap").
    - {!Entry_reconciliation.Through_entry} — a {b LIMIT} buy at ~the Friday
      close with the cap as its ceiling, quoting the overshoot. Price is already
      through the trigger, so rather than a MARKET order that chases the open,
      the ticket fills at or below the cap and refuses to chase past it. Risk is
      again the worst case (the cap).
    - {!Entry_reconciliation.Extended} — the {e same} resting stop-limit ticket
      as {!Entry_reconciliation.Valid_stop}, suffixed with a
      ["— WILL NOT FILL AT CURRENT PRICE: …"] clause naming the close, the
      overshoot, the entry and the limit, and stating that the order rests
      unfilled unless price returns into the entry-to-limit band. Issue #2404:
      the ticket used to be replaced by a do-not-chase suppression line, which
      made the artifact disagree with the order the backtest actually places and
      removed a confirmed breakout from the reader's view.

    A [0]-share candidate with no note (e.g. a short, which the live strategy
    leaves unsized) renders ["-"]; a [0]-share result {e with} a note renders
    that reason (cash / caps exhausted, invalid stop direction); a
    placeholder-sized candidate prefixes the ["UNSIZED — set portfolio.sexp"]
    note so the size reads as provisional. *)

val close_vs_entry : Weekly_snapshot.candidate -> string
(** Cell text for the "Close vs entry" column: the current close and the
    side-signed overshoot past the entry level, tagged with the class —
    ["$62.00 (+34.5% NO FILL)"], ["$25.44 (+7.3% through)"],
    ["$135.78 (-3.9%)"]. ["-"] when the candidate is
    {!Entry_reconciliation.Not_reconciled} (mechanism disarmed, or no resident
    bar to price it against). *)

val entry_reconciliation : string
(** Explains the "Close vs entry" column, the ["through"] / ["NO FILL"] tags and
    why a no-fill row still carries its order. Rendered below a candidate table
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

val resistance_grade_explainer : string
(** Explains what a candidate's resistance grade (["Virgin_territory (0.00)"],
    ["Heavy_resistance (0.82)"], …) means. Used as the HTML hover explainer on
    the resistance chip; single-sourced here so any renderer that surfaces it
    reads the same prose. *)

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

val eligible_beyond_cap :
  shown:Weekly_snapshot.candidate list -> beyond_cap:int -> string option
(** [eligible_beyond_cap ~shown ~beyond_cap] is the visibility note for the
    candidates the {e screener} dropped at its top-N cap — distinct from
    {!truncation}, which reports rows the {e report}'s own display limit hid.

    The screener admits the full eligible set, ranks it, and keeps only its top
    [max_buy_candidates]; [beyond_cap] is how many otherwise-eligible names it
    cut (see {!Weekly_snapshot.t.long_eligible_beyond_cap}). Since those names
    never reach the snapshot, no {!truncation} note can mention them; this one
    does, so a reader knows the shown list is a capped view of a larger eligible
    set (issue #2122 slice d).

    [None] when [beyond_cap <= 0] (nothing was cut — the [0] default of a
    pre-#2122 snapshot renders no line) or when [shown] is empty (no row to
    quote a cutoff score against). Otherwise a line naming the count and the
    lowest shown score — the score of the last (lowest-ranked) shown row, the
    bar the cut names fell just short of. *)

val score_breakdown : Weekly_snapshot.candidate -> string option
(** Compact arithmetic of {!Weekly_snapshot.candidate.score_components} —
    ["70 = 30 + 20 + 20"], the total (sum of the per-signal points, which equals
    the candidate's score by construction) followed by the points that composed
    it, in scoring order. The matching labels are the candidate's rationale
    clauses (same order) and the fuller labelled form is
    {!score_breakdown_detail}. [None] when the candidate carries no components —
    a snapshot written before the field existed, or one whose scoring produced
    no non-zero signal. *)

val score_breakdown_detail : Weekly_snapshot.candidate -> string option
(** Labelled decomposition of {!Weekly_snapshot.candidate.score_components} —
    ["30 Stage1→Stage2 breakout · 20 Strong volume · 20 RS positive & rising"],
    each signal's points beside its label. Used as the HTML hover explainer on
    the compact {!score_breakdown} figure. [None] on empty components. *)

val weaknesses : Weekly_snapshot.candidate -> string list
(** The weakest links in a candidate's setup, derived purely from data already
    on the row (no new scoring): an ["adequate (not strong) volume"]
    confirmation, a ["fallback stop (no structural floor)"], a ["wide risk N%"]
    to the stop, a ["paying up +N% through entry"] /
    ["+N% past cap, will not fill"] reconciliation, and — for long candidates —
    a ["sector not strong"]. Empty when the setup has none of these. Each phrase
    is factual and unwrapped (no markup). *)

val weakness_line : Weekly_snapshot.candidate -> string option
(** [weaknesses] joined with ["; "], or [None] when there are none — a single
    per-candidate line both renderers show so they cannot drift. *)
