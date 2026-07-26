(** Idempotent replacement of a comment-delimited block in a Markdown document.

    The README top-line results live between [<!-- toplines:start -->] /
    [<!-- toplines:end -->] marker lines so the block can be regenerated
    mechanically without disturbing the rest of the file. This module is the
    pure string surgery — no file I/O.

    Two layers are exposed: the {b generic} [render_between] / [upsert_between]
    take an arbitrary marker pair (used by the deep-headline block, which lives
    between its own [<!-- deep-headline:start -->] markers), and the {b default}
    [render] / [upsert] / [start_marker] / [end_marker] specialise them to the
    light-reference top-line block. *)

val render_between :
  start_marker:string -> end_marker:string -> string -> string
(** [render_between ~start_marker ~end_marker body] wraps [body] between the
    given marker lines (each on its own line), producing the full block text.
    The generic form of {!render}. *)

val upsert_between :
  start_marker:string ->
  end_marker:string ->
  document:string ->
  block:string ->
  string
(** [upsert_between ~start_marker ~end_marker ~document ~block] is the generic
    form of {!upsert}: it replaces the [start_marker]..[end_marker] region of
    [document] with [block], with the same semantics (append when absent,
    idempotent, raise on unterminated) documented for {!upsert}. Callers that
    manage several independent blocks in one file pass a distinct marker pair
    per block. *)

val start_marker : string
(** [<!-- toplines:start -->] — the opening sentinel line. *)

val end_marker : string
(** [<!-- toplines:end -->] — the closing sentinel line. *)

val render : string -> string
(** [render body] wraps [body] in the start/end markers, producing the full
    block text (markers on their own lines, [body] between them). [body] is the
    generated inner content (the period + the four-number table); the markers
    are added by this function so callers never hand-write them. *)

val upsert : document:string -> block:string -> string
(** [upsert ~document ~block] returns [document] with the marker-delimited
    region replaced by [block] (which must be a {!render}ed block — i.e. it
    begins with {!start_marker} and ends with {!end_marker}).

    - When [document] already contains a [start_marker]..[end_marker] region,
      everything from the start-marker line through the end-marker line
      (inclusive) is replaced by [block]; text before and after the region is
      preserved verbatim.
    - When [document] contains no such region, [block] is appended to the end of
      [document] (separated by a blank line if [document] is non-empty and does
      not already end in a newline).
    - Idempotent: [upsert ~document:(upsert ~document ~block) ~block] equals
      [upsert ~document ~block]. Regenerating with the same [block] is a no-op.

    @raise Invalid_argument
      if [document] contains a [start_marker] with no following [end_marker] (an
      unterminated block — refuse to silently corrupt the file). *)
