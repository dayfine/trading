open Core
open Weinstein_snapshot

let _placeholder_label = "UNSIZED — set portfolio.sexp"

(* A stop on the correct side of entry: below for a long, above for a short.
   Mirrors [Portfolio_risk.compute_position_size]'s own direction check — it
   returns 0 shares when the stop is on the wrong side. *)
let _stop_ok ~side ~entry ~stop =
  match side with
  | `Long -> Float.( < ) stop entry
  | `Short -> Float.( > ) stop entry

(* Reason a zero-share result occurred, surfaced from the sizing inputs rather
   than invented: an invalid stop direction is distinguished from cash / caps
   exhaustion. *)
let _zero_reason ~side ~entry ~stop =
  if not (_stop_ok ~side ~entry ~stop) then
    "0 sh — invalid stop direction (stop on wrong side of entry)"
  else "0 sh — cash / caps exhausted"

let _note ~placeholder ~side ~entry ~stop ~shares =
  if placeholder then Some _placeholder_label
  else if shares = 0 then Some (_zero_reason ~side ~entry ~stop)
  else None

let size_candidate ~risk_config ~portfolio_value ~sizing_cash ~side ~placeholder
    (c : Weekly_snapshot.candidate) : Weekly_snapshot.candidate =
  let sizing =
    Portfolio_risk.compute_position_size ~config:risk_config ~portfolio_value
      ~sizing_cash ~side ~entry_price:c.entry ~stop_price:c.stop ()
  in
  {
    c with
    sized_shares = sizing.shares;
    sized_position_value = sizing.position_value;
    sized_position_pct = sizing.position_pct;
    sized_risk_amount = sizing.risk_amount;
    sizing_note =
      _note ~placeholder ~side ~entry:c.entry ~stop:c.stop ~shares:sizing.shares;
  }
