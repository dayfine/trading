(** One long/short candidate rendered as a {!Report_card}.

    This is the only module that knows how a {!Weekly_snapshot.candidate}
    becomes chips, figures and an order ticket. {!Report_card} draws whatever it
    is handed; {!Chip} styles whatever it is handed; the mapping lives here.

    {1 Chips}

    In order: the score, then the screener's own rationale clauses, then the
    resistance grade, the stop kind, the data-suspect flag and the
    reconciliation class.

    {b The chip text is snapshot text, never a re-labelling.}
    [candidate.rationale] is a ["; "]-joined list of signal clauses
    (["Early Stage2; Strong volume; RS positive; …"]); each clause becomes one
    chip carrying that clause {e verbatim}. Only the CSS variant is derived, by
    matching a small recognised vocabulary. A clause the vocabulary does not
    know still renders — as a plain chip. That degradation is deliberate: the
    screener's vocabulary evolves, and a chip silently disappearing would be a
    loss of information, whereas printing a measurement the snapshot does not
    contain (e.g. turning ["Strong volume"] into ["3x volume"]) would be a
    fabrication.

    {1 Figures}

    [Entry], [Stop], [Risk] and — for a reconciled candidate — [Last].

    [Stop] keeps the trailing [*] of the Markdown report for a non-structural
    stop, so {!Report_shared.stop_fallback} (whose prose begins
    ["* fallback stop:"]) reads correctly beside it; the stop-kind chip states
    the same fact in words.

    [Risk] is quoted against {!Weekly_snapshot.expected_fill_price}, {b not}
    against [entry] — the same rule both renderers already follow. Quoting the
    risk of a fill that will not happen is issue #2103 restated one figure over.

    {1 Ticket}

    The bottom strip is {!Report_shared.instruction} verbatim, so the order text
    a reader copies into their broker is character-identical to the Markdown
    report's. An {!Entry_reconciliation.Extended} candidate — whose ticket
    {!Report_shared.instruction} suppresses — additionally marks the card and
    the strip, so a do-not-chase name reads as a different kind of row rather
    than as one more chip.

    Presentation only: no admission, entry, stop or sizing rule is evaluated
    here. Every number rendered is read off the snapshot or off
    {!Report_shared}. *)

val render :
  arm:string ->
  rank:int ->
  chart:string option ->
  Weekly_snapshot.candidate ->
  string
(** [render ~arm ~rank ~chart candidate] is the candidate's card.

    [arm] is ["long"] or ["short"] and reaches the page as the [data-chart]
    prefix, keeping the two arms separately assertable. [rank] is the display
    position within its section. [chart] is the already-rendered inline SVG, or
    [None] when the caller had too few bars — the card then shows the
    ["no chart data"] marker and is otherwise complete.

    Pure function: no I/O, deterministic. Every snapshot-sourced string is
    escaped. *)
