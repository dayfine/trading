(** Shared per-row check plumbing: the {!step} outcome, the {!finding}
    accumulator, and the fold + lookup combinators the check modules build on.
*)

open Core
open Validator_types

(** Per-row outcome: could-not-evaluate ({!Skip}), clean ({!Pass}), or a
    violation carrying its specimen ({!Fail}). *)
type step = Skip | Pass | Fail of specimen

type finding = { violations : specimen list; skipped : int }
(** Accumulated violations (newest-first) + count of un-evaluable rows. *)

val empty_finding : finding
(** The zero accumulator: no violations, nothing skipped. *)

val fold_steps : 'a list -> f:('a -> step) -> finding
(** Fold [f] over [rows], absorbing each {!step} into a {!finding}. *)

val spec : trade_row -> string -> specimen
(** Build a specimen from a trade row + an offending-value [detail]. *)

val open_spec : open_row -> string -> specimen
(** Build a specimen from an open-position row + [detail]. *)

val longs : inputs -> trade_row list
(** The LONG trades of [inputs]. *)

val audit_step :
  (trade_row -> entry_context option) ->
  pred:(trade_row -> entry_context -> step) ->
  trade_row ->
  step
(** Dispatch a trade with an audit record to [pred]; a row with no audit record
    is {!Skip}. *)

val bars_context : inputs -> trade_row -> (bars * int) option
(** The entry-week index for a trade with basis-consistent bars. [None] when
    bars are missing, the entry week can't be located, or the entry-week close
    disagrees with the fill price (post-run split rebasing). *)

val wbars_step :
  inputs -> pred:(trade_row -> bars -> int -> step) -> trade_row -> step
(** Dispatch a trade with a valid {!bars_context} to [pred]; otherwise {!Skip}.
*)

val dollar_adv : bars -> as_of:Date.t -> lookback:int -> float option
(** Mean daily [close * volume] over the last [lookback] daily bars at or before
    [as_of]. [None] when no bars precede [as_of]. *)
