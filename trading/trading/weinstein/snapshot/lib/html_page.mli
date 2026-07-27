(** HTML page scaffolding for the weekly report — escaping, the stylesheet, and
    the document shell. Pure string functions; no I/O.

    Split out of {!Html_report_renderer} so the (verbose, rarely-read)
    stylesheet does not crowd out the (frequently-read) section-assembly logic.
*)

val escape : string -> string
(** [escape s] replaces the five XML metacharacters with their HTML entities.

    Every snapshot-sourced string — symbol, grade, sector, rationale, sizing
    note, warning line, chart label — passes through this before reaching the
    output. Snapshot text originates in vendor feeds and config files, so
    treating it as trusted markup would be a correctness bug, not just a
    hardening gap. Escaping the ampersand first is what keeps the transformation
    from double-encoding the entities it just introduced. *)

val css : string
(** The report's complete stylesheet, emitted inline in a [<style>] element so
    the page is self-contained (no external assets, no network fetch, no JS
    required to read it).

    Colours are declared as CSS custom properties with a
    [prefers-color-scheme: dark] override, so the light and dark palettes swap
    in one place. The chart palette is deliberate: the close-price polyline
    wears neutral ink (single-series charts do not need a categorical hue),
    while the {b entry} line is blue and the {b stop} line is red — a validated
    warm/cool pair that reads as opposite, separable under every simulated
    colour-vision deficiency. Each level line also carries a distinct dash
    pattern, so identity never rests on colour alone. Volume bars are a
    recessive gray: they are supporting texture, not the subject. *)

val document : title:string -> body:string -> string
(** [document ~title ~body] wraps [body] in a complete HTML5 document — doctype,
    [<meta charset>], the viewport meta, the escaped [title], and {!css} inline
    — terminated by a final newline.

    [body] is inserted verbatim: it is renderer-generated markup, so the caller
    is responsible for having escaped any snapshot-sourced text it contains. *)
