(* Price-banded tier tables for short-side margin mechanics — see [.mli].

   The lookup is a pure, order-independent, piecewise-constant selection: the
   tightest band that still covers the marked price wins, falling back to the
   caller's flat value (which is what makes an empty table a bit-identical
   no-op). *)

open Core

type tier = { price_below : float; value : float } [@@deriving show, eq, sexp]

let _covers ~price tier = Float.O.(price < tier.price_below)

let tier_value ~(tiers : tier list) ~(flat_fallback : float) ~(price : float) :
    float =
  match List.filter tiers ~f:(_covers ~price) with
  | [] -> flat_fallback
  | covering ->
      let tightest =
        List.min_elt covering ~compare:(fun a b ->
            Float.compare a.price_below b.price_below)
      in
      (Option.value_exn tightest).value
