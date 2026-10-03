(** Ticket-anchor choice for a screened candidate. See
    [screener_entry_anchor.mli]. *)

open Core

type kind = Continuation | Local_range_top | Breakout | Ma_fallback
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

let choose ~is_short (a : Stock_analysis.t) : kind * float option =
  let continuation = if is_short then None else _continuation_anchor a in
  match (continuation, a.local_range_top) with
  | Some h, _ -> (Continuation, Some h)
  | None, Some top -> (Local_range_top, Some top)
  | None, None when Option.is_some a.breakout_price -> (Breakout, None)
  | None, None -> (Ma_fallback, None)
