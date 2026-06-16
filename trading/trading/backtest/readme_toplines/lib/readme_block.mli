(** Idempotent replacement of a comment-delimited block in a Markdown document.

    The README top-line results live between [<!-- toplines:start -->] /
    [<!-- toplines:end -->] marker lines so the block can be regenerated
    mechanically without disturbing the rest of the file. This module is the
    pure string surgery — no file I/O. *)

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
