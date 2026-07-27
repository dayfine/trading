(** Right-margin label layout for {!Svg_chart} — the collision-avoidance rule,
    kept apart from the chart's geometry so neither file has to be read to
    understand the other.

    A chart's level lines (entry, stop) are named in a gutter reserved at the
    right of the plot. Two levels a few cents apart project to nearly the same
    [y]; drawn at their natural baselines their text overprints and neither is
    readable. This module lays a set of labels out so that never happens.

    It knows nothing about prices, charts or snapshots — it is handed CSS
    classes, text and target baselines, and returns SVG [<text>] elements. *)

val gutter : float
(** Width to reserve at the right of the plot for labels, in viewBox units. A
    chart drawn without labels reserves nothing. *)

val inset : float
(** Gap between the plot's right edge and the start of a label. *)

val baseline_offset : float
(** How far {b below} its line a label's baseline sits, so the text reads as
    attached to the line rather than bisected by it. Callers add this to the
    line's [y] to get the label's target baseline. *)

type placement = {
  cls : string;  (** CSS class for the [<text>] element. *)
  text : string;  (** Label text. Escaped on render. *)
  y : float;  (** Target baseline — where the label would sit unobstructed. *)
}
(** One label's requested placement. *)

val render : x:float -> placement list -> string list
(** [render ~x placements] is one [<text>] element per placement, all at [x].

    Baselines are laid out top to bottom and each is pushed down until it clears
    the one above it by a minimum gap, so no two labels overprint. The pushing
    is done in [y] order; the {b returned list keeps the caller's order}, so the
    emitted markup is stable no matter how the labels end up stacked.

    Text is escaped via {!Html_page.escape}. Pure function: no I/O. *)
