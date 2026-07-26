(* Price-banded tier tables for short-side margin mechanics — see [.mli].

   The lookup is a pure, order-independent, piecewise-constant selection: the
   tightest band that still covers the marked price wins, falling back to the
   caller's flat value (which is what makes an empty table a bit-identical
   no-op). *)

open Core

type tier = { price_below : float; value : float } [@@deriving show, eq, sexp]

let _covers ~price tier = Float.O.(price < tier.price_below)
let _by_price_below a b = Float.compare a.price_below b.price_below

let tier_value ~(tiers : tier list) ~(flat_fallback : float) ~(price : float) :
    float =
  (* Tightest covering band = the smallest [price_below] still above [price];
     [List.min_elt] returns [None] for the empty / no-cover case → fallback. *)
  let covering = List.filter tiers ~f:(_covers ~price) in
  match List.min_elt covering ~compare:_by_price_below with
  | None -> flat_fallback
  | Some tightest -> tightest.value
