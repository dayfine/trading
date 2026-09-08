(** Per-macro-state fallback initial-stop width. See [stop_buffer_by_state.mli].
*)

open Core

(* Sentinel: "this state has no width of its own". A buffer multiplies the entry
   price, so 0.0 cannot be a meaningful width — see the [.mli]. *)
let unset = 0.0

type t = {
  bullish : float; [@sexp.default unset]
  neutral : float; [@sexp.default unset]
  deteriorating : float; [@sexp.default unset]
  recovering : float; [@sexp.default unset]
  bearish : float; [@sexp.default unset]
}
[@@deriving sexp, equal]

let default =
  {
    bullish = unset;
    neutral = unset;
    deteriorating = unset;
    recovering = unset;
    bearish = unset;
  }

let is_no_op t = equal t default

(* Exhaustive by construction: a sixth [breadth_state] breaks the build here. *)
let _slot_for t (state : Weinstein_types.breadth_state) =
  match state with
  | Bullish_breadth -> t.bullish
  | Neutral_breadth -> t.neutral
  | Deteriorating -> t.deteriorating
  | Recovering -> t.recovering
  | Bearish_breadth -> t.bearish

let buffer_for t ~fallback ~state =
  let slot = _slot_for t state in
  if Float.( <= ) slot unset then fallback else slot
