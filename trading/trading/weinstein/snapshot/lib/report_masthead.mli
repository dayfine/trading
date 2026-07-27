(** Page furniture for the HTML weekly report — the masthead, the counts strip,
    the chart legend and the closing notes.

    Split out of {!Html_report_renderer} so that module stays a composer: it
    decides what sections exist and in what order, while the prose and markup of
    the surrounding furniture live here.

    None of this is shared with the Markdown report, which has no masthead — so
    unlike the legends and the order ticket (which live in {!Report_shared}
    precisely because both formats print them), this prose has nothing to drift
    against. *)

val header : Weekly_snapshot.t -> title:string -> string
(** [header snapshot ~title] is the [<header>] block: the report title, the
    as-of date and producing system version, and a chip stating the macro regime
    and its score.

    The regime chip's CSS variant is taken from a {b closed} set (bullish /
    bearish / neutral); any other regime label renders as a plain chip rather
    than injecting a class name derived from snapshot text. *)

val counts_strip : Weekly_snapshot.t -> string
(** [counts_strip snapshot] is the tile strip of section counts — long
    candidates, short candidates, held positions, data-quality warnings.

    The counts are of the {b full} snapshot lists, not of the display-capped
    tables, so a reader can tell "7 shown of 20 found" from "7 found". The
    per-section truncation note ({!Report_shared.truncation}) states the
    difference. *)

val chart_legend : ma_period:int -> string
(** [chart_legend ~ma_period] names each mark a candidate chart draws: the close
    line, the [ma_period]-period moving average, the dashed entry and stop
    levels, and the fact that a symbol is a TradingView link.

    One legend per candidate section rather than one per chart: the marks are
    identical on every card, and a section that renders on its own still carries
    the key to its own charts. *)

val closing_notes : string
(** How to read the report, and what its figures do and do not promise: the
    chips are the screener's own rationale clauses; a [*] stop is the
    fixed-buffer proxy rather than a chart level; an unfilled buy-stop costs
    nothing and should be cancelled at Friday close.

    Deliberately free of numeric thresholds. The risk fraction, the per-position
    cap and the stop buffer are configuration this renderer is not handed, and
    printing plausible-looking values for them would be a fabrication. *)
