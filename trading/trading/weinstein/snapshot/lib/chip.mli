(** Tag chip — the one small presentation primitive the HTML weekly report uses
    wherever a short labelled fact sits beside a symbol, a sector or the
    masthead.

    A chip is a piece of {b text} plus an optional {b modifier}. The text is the
    fact; the modifier only selects a CSS variant ({!Html_page.css} styles
    [.chip-<modifier>]). Identity therefore never rests on colour alone — the
    label always spells out what the colour is saying, which is the
    accessibility rule the report's charts already follow for their dashed level
    lines.

    The module is {b snapshot-independent}: it knows nothing about candidates or
    positions. Deriving chips from a {!Weekly_snapshot.candidate} is
    {!Candidate_card}'s job. *)

type t = {
  text : string;
      (** The fact the chip states, e.g. ["Strong volume"] or ["fallback stop"].
          Escaped on render; callers pass plain text. *)
  modifier : string option;
      (** CSS variant selector. [Some "vol-strong"] renders
          [class="chip chip-vol-strong"]; [None] renders the plain
          [class="chip"] used for any fact with no special treatment.

          A modifier the stylesheet does not know still renders — the chip
          degrades to the plain appearance rather than disappearing. That is
          deliberate: screener vocabulary evolves, and a chip vanishing from the
          report would be a silent loss of information. *)
}

val make : ?modifier:string -> string -> t
(** [make ?modifier text] is the chip stating [text]. *)

val render : t -> string
(** [render chip] is the [<span class="chip …">…</span>] element, with [text]
    escaped via {!Html_page.escape}. *)

val render_all : t list -> string
(** [render_all chips] concatenates {!render} over [chips], with no separator —
    spacing is the stylesheet's job. [[]] renders as the empty string. *)

val group : ?cls:string -> t list -> string
(** [group ?cls chips] wraps {!render_all} in a [<span>] container so a run of
    chips lays out as one unit. [cls] defaults to ["chips"]. *)
