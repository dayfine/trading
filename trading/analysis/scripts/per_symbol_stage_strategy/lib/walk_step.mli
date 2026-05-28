(** Per-week step kernel for the per-symbol stage strategy backtest.

    Holds the position state machine (Flat / Long / Short), the cost-model
    pricing rule, the mark-to-market equity formula, and the trade-record
    bookkeeping. Reused by {!Single_symbol_backtest} which threads these
    primitives through the chronological walk over weekly bars.

    Pure functions; refs only inside the [walk_state] record (mutable fields).
*)

open Core

(** Single position held by the diagnostic. The strategy holds at most ONE long
    or short at a time — no diversification. *)
type position =
  | Flat
  | Long of { shares : float; entry_date : Date.t; entry_price : float }
  | Short of { shares : float; entry_date : Date.t; entry_price : float }

type trade = {
  variant_side : [ `Long | `Short ];
  entry_date : Date.t;
  exit_date : Date.t;
  entry_price : float;
  exit_price : float;
  return_pct : float;
}
[@@deriving show, eq]
(** Per-trade record exposed for the result type. *)

val adjusted_prices : bid_ask_bps:float -> close:float -> float * float
(** [adjusted_prices ~bid_ask_bps ~close] is [(buy_px, sell_px)] where buy fills
    pay [close * (1 + bps/10000)] and sell fills receive
    [close * (1 - bps/10000)]. The symmetric half-spread cost charged on every
    fill. *)

val mtm_equity : cash:float -> position:position -> close:float -> float
(** [mtm_equity ~cash ~position ~close] is the mark-to-market equity given the
    cash balance, current position, and current period's close price.

    For long: [cash + shares * close]. For short: [cash - shares * close]. The
    [cash] balance for a short already includes the short proceeds (we move
    [shares * sell_px] into [cash] on entry); the liability to cover at [close]
    is [shares * close], so subtraction gives the realisable equity. *)

val step :
  action:Stage_signal.action ->
  close:float ->
  date:Date.t ->
  bid_ask_bps:float ->
  cash:float ->
  position:position ->
  float * position * trade option
(** [step ~action ~close ~date ~bid_ask_bps ~cash ~position] applies the week's
    signal-derived action and returns [(cash', position', completed_trade_opt)].

    Sizing:
    - Entry actions deploy 100% of cash (fractional shares allowed — the
      diagnostic does not enforce whole-share rounding).
    - Exit actions liquidate the entire position.

    Mismatched (action, position) pairs (e.g. [Exit_long] on [Flat], or
    [Enter_long] on existing [Long]) collapse to [Hold] — no state change. *)

val force_close_at_end :
  position:position ->
  cash:float ->
  final_bar:Types.Daily_price.t ->
  bid_ask_bps:float ->
  float * position * trade option
(** [force_close_at_end ~position ~cash ~final_bar ~bid_ask_bps] closes any open
    position at the final bar's close, charging the cost-model half-spread. Used
    by the runner to realise any still-open trade so the final equity reflects
    cash-only state and the equity curve's last sample is comparable across runs
    that did or did not have positions open at the window's end.

    Returns [(cash', Flat, completed_trade_opt)]. When [position = Flat],
    returns [(cash, Flat, None)] — no-op. *)
