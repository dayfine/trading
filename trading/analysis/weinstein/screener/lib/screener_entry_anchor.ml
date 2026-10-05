(** Ticket-anchor choice for a screened candidate. See
    [screener_entry_anchor.mli]. *)

open Core

type kind =
  | Continuation
  | Local_range_top
  | Breakout
  | Breakdown
  | Ma_fallback
[@@deriving sexp, show, eq]

(* Continuation-buy ticket anchor (#3056): the detector's [consolidation_high]
   when the Ch. 3 continuation pattern fired ([is_continuation = true]), else
   [None]. [a.continuation] is [Some _] only when the strategy armed the
   detector ([Weinstein_strategy_config.enable_continuation_buys]), so with the
   flag off this is always [None]. *)
let _continuation_anchor (a : Stock_analysis.t) : float option =
  match a.continuation with
  | Some { is_continuation = true; consolidation_high; _ } -> consolidation_high
  | Some _ | None -> None

(* Long arms: continuation, local range top, base top, MA fallback. *)
let _choose_long (a : Stock_analysis.t) : kind * float option =
  match (_continuation_anchor a, a.local_range_top) with
  | Some h, _ -> (Continuation, Some h)
  | None, Some top -> (Local_range_top, Some top)
  | None, None when Option.is_some a.breakout_price -> (Breakout, None)
  | None, None -> (Ma_fallback, None)

(* Short arms (#3131): the support floor, else the MA fallback. A short never
   takes a top arm: its sell-stop goes under support (book Ch. 7). *)
let _choose_short (a : Stock_analysis.t) : kind * float option =
  match a.breakdown_price with
  | Some floor -> (Breakdown, Some floor)
  | None -> (Ma_fallback, None)

let choose ~is_short (a : Stock_analysis.t) : kind * float option =
  if is_short then _choose_short a else _choose_long a
