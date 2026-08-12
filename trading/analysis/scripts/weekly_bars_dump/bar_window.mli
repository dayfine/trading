(** Pure weekly-bar window selection for the blind-judge sanity-check harness
    (see [.claude/skills/blind-judge/SKILL.md]).

    A [through] spec picks the "decision week" -- the last weekly bar the judge
    is allowed to see. {!select} slices the trailing window ending there. This
    is the load-bearing lookahead guard for the whole harness: a judge that ever
    sees a bar after the decision week is answering a different, easier question
    ("what happened next"), not the one we are trying to sanity-check ("would a
    book-faithful reader place a ticket here, knowing only the past"). *)

open Core

type through =
  | By_date of Date.t
  | By_index of int
      (** 0-based position into the full chronological (oldest-first) weekly
          series. *)

val select :
  weekly:Types.Daily_price.t list ->
  through:through ->
  weeks_back:int ->
  Types.Daily_price.t list Status.status_or
(** [select ~weekly ~through ~weeks_back] returns the trailing window of at most
    [weeks_back] weekly bars from [weekly] (chronologically ascending, oldest
    first) ending at and including the decision bar resolved by [through]:
    - [By_date d]: the bar whose [date = d]. [Error Not_found] if no bar in
      [weekly] carries that exact date.
    - [By_index i]: the bar at 0-based position [i] in [weekly].
      [Error Invalid_argument] if [i] is out of [\[0, List.length weekly)].

    The result is chronologically ascending, oldest first, decision week last.
    {b Lookahead invariant}: no returned bar is ever dated later than the
    resolved decision bar -- guaranteed by construction (the result is a prefix
    slice of [weekly] ending at the decision index), and pinned by a dedicated
    test.

    [Error Invalid_argument] if [weeks_back <= 0]. *)

val trailing_average_close :
  Types.Daily_price.t list -> period:int -> float option
(** [trailing_average_close bars ~period] is the simple average of [close_price]
    (raw, unadjusted -- the same basis {!select}'s bars carry) over the last
    [period] entries of [bars] (chronologically ascending; the decision week is
    the last entry), or [None] if [List.length bars < period]. Pure arithmetic:
    callers (the CLI's [--with-ma] flag) decide whether to surface it. *)
