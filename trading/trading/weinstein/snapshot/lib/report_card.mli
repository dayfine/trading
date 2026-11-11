(** One card in the HTML weekly report — the layout unit that replaced the
    report's candidate/held tables.

    A card stacks three strips inside a [div.cand]:

    - [div.cand-main] — rank, the symbol (a TradingView link), the {!Chip} run,
      and the numeric stack,
    - [div.chart] — the inline sparkline, tagged [data-chart="<arm>:<symbol>"],
    - [div.ticket] — the executable line (an order ticket, or a position line
      for a held name).

    The module is {b snapshot-independent}: it is handed already-derived chips,
    numbers, chart and footer. Turning a {!Weekly_snapshot.candidate} into those
    is {!Candidate_card}'s job. That split is what lets the long, short and held
    arms share one scaffold without the scaffold knowing which arm it is
    drawing. *)

type num = {
  label : string;  (** Small caption above the value, e.g. ["Entry"]. *)
  value : string;  (** Pre-formatted value, e.g. ["$141.29"]. *)
  modifier : string option;
      (** CSS variant for the value ([Some "entry"] renders
          [class="num-value num-entry"]), so entry and stop read in their chart
          colours. [None] leaves the value unstyled. *)
}
(** One labelled figure in the card's numeric stack. Both strings are escaped on
    render. *)

val num : ?modifier:string -> label:string -> string -> num
(** [num ?modifier ~label value] is one entry of the numeric stack. *)

type footer = {
  body : string;
      (** {b Raw HTML}, not escaped — the ticket line carries its own inline
          emphasis. Every caller in this library builds it from escaped pieces;
          a caller passing snapshot text straight through would be introducing
          the injection this library escapes everywhere else. *)
  modifier : string option;
      (** CSS variant for the strip ([Some "suppressed"] renders
          [class="ticket ticket-suppressed"]). *)
}
(** The card's bottom strip. *)

val footer : ?modifier:string -> string -> footer
(** [footer ?modifier body] is the bottom strip carrying raw HTML [body]. *)

type t = {
  modifier : string option;
      (** CSS variant for the whole card ([Some "extended"] renders
          [class="cand cand-extended"]), so a do-not-chase name is visibly a
          different kind of row rather than one more chip. *)
  arm : string;
      (** Which rendering arm this card belongs to — ["long"], ["short"] or
          ["held"]. Emitted in [data-chart] so the three arms stay separately
          assertable by anything reading the page programmatically. *)
  rank : int option;
      (** Display rank within its section. [None] for an unranked arm (held
          positions), which then renders no rank cell. *)
  symbol : string;  (** Ticker. Becomes the card heading and the chart tag. *)
  chips : Chip.t list;  (** Fact chips, rendered in the given order. *)
  nums : num list;  (** The numeric stack, rendered in the given order. *)
  chart : string option;
      (** Inline SVG for this symbol, or [None] when there were not enough bars
          — in which case the chart strip renders the ["no chart data"] marker
          and the rest of the card is unaffected. *)
  footer : footer option;
      (** The executable line. [None] renders no bottom strip at all (rather
          than an empty one). *)
}

val tradingview_href : string -> string
(** [tradingview_href symbol] is the TradingView chart URL for [symbol].

    A plain external link — not an asset — so the page stays self-contained: it
    still inlines every stylesheet and every chart, references no external
    resource, and needs no JavaScript to read.

    The symbol is escaped for attribute context, so a malformed ticker yields a
    dead link rather than an attribute breakout. The scheme and host are fixed
    here, never taken from snapshot data. *)

val render : t -> string
(** [render card] is the complete [<div class="cand …">…</div>] element.

    Every string sourced from the snapshot is escaped, except {!footer.body},
    which is documented raw HTML. Pure function: no I/O, deterministic. *)
