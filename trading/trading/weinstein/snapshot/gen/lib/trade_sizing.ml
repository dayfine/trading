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

(* An over-extended candidate has no ticket, so it has no size. Zeroed
   explicitly rather than left alone: a caller re-sizing an already-sized
   candidate must not keep a stale share count beside a suppressed order. *)
let _unsized (c : Weekly_snapshot.candidate) =
  {
    c with
    sized_shares = 0;
    sized_position_value = 0.0;
    sized_position_pct = 0.0;
    sized_risk_amount = 0.0;
    sizing_note = None;
  }

(* Issue #2103: sizing is anchored to the price the order would actually fill
   at, never to the (possibly weeks-stale) breakout level in [c.entry]. *)
let _sized ~risk_config ~portfolio_value ~sizing_cash ~side ~placeholder
    (c : Weekly_snapshot.candidate) =
  let fill = Weekly_snapshot.expected_fill_price c in
  let sizing =
    Portfolio_risk.compute_position_size ~config:risk_config ~portfolio_value
      ~sizing_cash ~side ~entry_price:fill ~stop_price:c.stop ()
  in
  {
    c with
    sized_shares = sizing.shares;
    sized_position_value = sizing.position_value;
    sized_position_pct = sizing.position_pct;
    sized_risk_amount = sizing.risk_amount;
    sizing_note =
      _note ~placeholder ~side ~entry:fill ~stop:c.stop ~shares:sizing.shares;
  }

let size_candidate ~risk_config ~portfolio_value ~sizing_cash ~side ~placeholder
    (c : Weekly_snapshot.candidate) : Weekly_snapshot.candidate =
  match c.reconciliation with
  | Entry_reconciliation.Extended _ -> _unsized c
  | Not_reconciled | Valid_stop _ | Through_entry _ ->
      _sized ~risk_config ~portfolio_value ~sizing_cash ~side ~placeholder c
