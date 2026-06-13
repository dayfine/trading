open Core
open Status
open Trading_base.Types

let _negligible_quantity_epsilon = 1e-9

let _is_quantity_negligible (qty : float) : bool =
  Float.(abs qty < _negligible_quantity_epsilon)

(* A trade is closing when it is opposite-signed to a non-flat position. *)
let _is_closing ~existing_qty ~trade_qty_signed : bool =
  (not (_is_quantity_negligible existing_qty))
  && not
       (Bool.equal
          Float.O.(existing_qty >= 0.0)
          Float.O.(trade_qty_signed >= 0.0))

let _signed_trade_quantity (trade : trade) : float =
  match trade.side with Buy -> trade.quantity | Sell -> -.trade.quantity

(* Cash outflow of the opening [opening_qty] shares of a flip, with commission
   attributed pro-rata by the opening share fraction. The opening portion of a
   short-cover flip is always a Buy growing a new long, so the change is a cash
   outflow (negative). [opening_qty] is 0.0 for a genuinely-reducing trade, in
   which case the result is 0.0 (no new cash exposure). *)
let _opening_cash_outflow ~trade_qty_abs ~opening_qty (trade : trade) : float =
  if _is_quantity_negligible opening_qty then 0.0
  else
    let opening_fraction = opening_qty /. trade_qty_abs in
    let opening_commission = trade.commission *. opening_fraction in
    -.((opening_qty *. trade.price) +. opening_commission)

(* The cash impact attributable to the *opening* portion of a closing trade.
   [None] when the trade is not a closing trade against a non-flat position
   (caller applies the floor to the full [cash_change]). [Some opening_change]
   otherwise: 0.0 for a genuinely-reducing trade, or the opening-portion cash
   change for an over-cover. Mirrors [Portfolio_margin._classify_trade]'s
   [Float.min trade.quantity (Float.abs existing_qty)] split. *)
let _opening_portion_cash_change ~existing_qty (trade : trade) : float option =
  let trade_qty_signed = _signed_trade_quantity trade in
  if not (_is_closing ~existing_qty ~trade_qty_signed) then None
  else
    let trade_qty_abs = Float.abs trade.quantity in
    let closed_qty = Float.min trade_qty_abs (Float.abs existing_qty) in
    let opening_qty = trade_qty_abs -. closed_qty in
    Some (_opening_cash_outflow ~trade_qty_abs ~opening_qty trade)

let _floor_error ~current_cash ~cash_change ~negative_unrealized_pnl =
  error_invalid_argument
    ("Insufficient cash for trade. Required: "
    ^ Float.to_string (-.cash_change)
    ^ ", Available: "
    ^ Float.to_string current_cash
    ^ ", Unrealized loss drag: "
    ^ Float.to_string negative_unrealized_pnl)

(* Apply the absolute-dollar floor against [checked_change]:
   [current_cash + checked_change + negative_unrealized_pnl >= 0]. Returns the
   post-trade balance [new_cash] on success. *)
let _floor_check ~current_cash ~negative_unrealized_pnl ~new_cash ~cash_change
    ~checked_change =
  let effective_cash =
    current_cash +. checked_change +. negative_unrealized_pnl
  in
  if Float.(effective_cash < 0.0) then
    _floor_error ~current_cash ~cash_change ~negative_unrealized_pnl
  else Result.Ok new_cash

let check ~exempt ~current_cash ~negative_unrealized_pnl ~existing_qty ~trade
    ~cash_change =
  let new_cash = current_cash +. cash_change in
  let exemption =
    if exempt then _opening_portion_cash_change ~existing_qty trade else None
  in
  match exemption with
  | None ->
      _floor_check ~current_cash ~negative_unrealized_pnl ~new_cash ~cash_change
        ~checked_change:cash_change
  | Some opening_change ->
      if _is_quantity_negligible opening_change then
        (* Genuinely-reducing closing trade: exempt from the floor entirely. *)
        Result.Ok new_cash
      else
        (* Over-cover: only the new-opening portion faces the floor. *)
        _floor_check ~current_cash ~negative_unrealized_pnl ~new_cash
          ~cash_change ~checked_change:opening_change
