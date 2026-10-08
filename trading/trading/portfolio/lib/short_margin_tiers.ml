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

(* FINRA Rule 4210(c) short maintenance, per share: under $5 the greater of
   $2.50 and 100 % of the mark; at $5 or above the greater of $5.00 and 30 %. *)
let _finra_low_price_cutoff = 5.0
let _finra_low_price_per_share = 2.50
let _finra_low_price_ratio = 1.0
let _finra_per_share = 5.0
let _finra_ratio = 0.30

let finra_short_maintenance ~price =
  if Float.(price <= 0.0) then _finra_low_price_ratio
  else if Float.(price < _finra_low_price_cutoff) then
    Float.max _finra_low_price_ratio (_finra_low_price_per_share /. price)
  else Float.max _finra_ratio (_finra_per_share /. price)
