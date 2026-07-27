(** Shared legend / footnote prose for the weekly-report renderers.

    {!Report_renderer} (Markdown) and {!Html_report_renderer} (HTML) render the
    same weekly snapshot in two formats. Both must explain the same three things
    below a candidate table:

    - a {b fallback stop} — the candidate's [stop] is the fixed
      [entry * initial_stop_buffer] proxy rather than a real structural level
      (issue #2084 Finding 2),
    - a {b data-suspect} candidate — its most recent bar is a single outsized
      move, so the row is flagged but kept (issue #2083 Finding 3),
    - a {b truncated table} — how many candidates were hidden and how many of
      them tie the cutoff score.

    The prose lives here, once, so the two renderers cannot drift. Each string
    is returned {b unwrapped} — no Markdown emphasis, no HTML tags. The caller
    supplies its own wrapping ([_..._] for Markdown, [<p class="note">] for
    HTML). *)

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
