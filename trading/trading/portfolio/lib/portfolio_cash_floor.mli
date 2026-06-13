(** Cash-floor solvency check for {!Portfolio.apply_single_trade}, extracted so
    [portfolio.ml] stays under the file-length limit.

    The floor is an absolute-dollar solvency check:
    [current_cash + checked_change + negative_unrealized_pnl >= 0], where
    [negative_unrealized_pnl] is the (non-positive) sum of paper losses on open
    positions. [checked_change] is normally the full trade cash change.

    NS1 (#1557#3) closing-trade exemption: when [exempt = true], the reducing
    portion of a closing trade (long sell / short cover) bypasses the floor,
    because it reduces risk and must not be blocked by stale paper-loss drag
    (the #1553 zombie root cause). A genuinely-reducing trade
    ([|trade_qty| <= |existing_qty|]) is accepted unconditionally; an over-cover
    that flips direction exempts the closing portion but still applies the floor
    to the new-opening portion's cash change. The split mirrors
    [Portfolio_margin._classify_trade]'s [min(|trade_qty|, |existing_qty|)]. *)

open Trading_base.Types
open Status
open Types

val check :
  exempt:bool ->
  current_cash:cash_value ->
  negative_unrealized_pnl:float ->
  existing_qty:float ->
  trade:trade ->
  cash_change:cash_value ->
  cash_value status_or
(** [check ~exempt ~current_cash ~negative_unrealized_pnl ~existing_qty ~trade
     ~cash_change] returns [Ok new_cash] (where
    [new_cash = current_cash +. cash_change]) when the floor is satisfied, or an
    [Error] describing the shortfall.

    @param exempt
      NS1 closing-trade exemption flag. [false] reproduces the legacy floor (the
      full [cash_change] faces the check) exactly.
    @param current_cash Cash balance before the trade.
    @param negative_unrealized_pnl
      Sum of [min 0.0 pnl] over open positions (a non-positive paper-loss drag).
    @param existing_qty
      Signed quantity of the existing position in [trade.symbol] (0.0 if none).
    @param trade The trade being applied.
    @param cash_change Full cash change of [trade] (negative for a Buy). *)
