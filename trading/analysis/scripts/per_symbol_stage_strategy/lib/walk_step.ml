open Core

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

(* One-sided half-spread cost applied symmetrically on every fill. The
   pair [(buy_px, sell_px)] is precomputed per call to keep [step]'s match
   arms terse. *)
let adjusted_prices ~bid_ask_bps ~close =
  let adj = bid_ask_bps /. 10_000.0 in
  let buy_px = close *. (1.0 +. adj) in
  let sell_px = close *. (1.0 -. adj) in
  (buy_px, sell_px)

(* For long: cash + shares * close.
   For short: post-short, [cash] already includes the short proceeds
   ([cash := cash + shares * sell_px] in entry); the liability to cover
   at [close] is [shares * close], so equity = cash - shares * close.

   Verify: open short at $100/share with $1M starting cash. Shares = 10000,
   proceeds = $1M, post-cash = $2M. Equity at entry = 2M - 10000*100 = $1M
   (unchanged from start, correct). If price doubles to $200, equity = 2M -
   10000*200 = $0 (100% loss on a doubling-against-the-short, correct). *)
let mtm_equity ~cash ~position ~close =
  match position with
  | Flat -> cash
  | Long { shares; _ } -> cash +. (shares *. close)
  | Short { shares; _ } -> cash -. (shares *. close)

let _record_long_close ~entry_date ~entry_price ~exit_date ~exit_price : trade =
  let return_pct = (exit_price -. entry_price) /. entry_price in
  {
    variant_side = `Long;
    entry_date;
    exit_date;
    entry_price;
    exit_price;
    return_pct;
  }

let _record_short_close ~entry_date ~entry_price ~exit_date ~exit_price : trade
    =
  (* Short return = inverse of price move. Negative price move = positive
     trade return. *)
  let return_pct = (entry_price -. exit_price) /. entry_price in
  {
    variant_side = `Short;
    entry_date;
    exit_date;
    entry_price;
    exit_price;
    return_pct;
  }

(* Edge cases:
   - Enter_long on Flat: shares = cash / buy_px (fractional shares allowed
     — diagnostic, no whole-share rounding); zero cash leftover.
   - Enter_long on Long/Short: no-op (Hold). Already in a position.
   - Exit_long on Flat: no-op. Nothing to exit.
   - Symmetric for short.
*)
let step ~action ~close ~date ~bid_ask_bps ~cash ~position =
  let buy_px, sell_px = adjusted_prices ~bid_ask_bps ~close in
  match (action, position) with
  | Stage_signal.Enter_long, Flat ->
      let shares = cash /. buy_px in
      (0.0, Long { shares; entry_date = date; entry_price = buy_px }, None)
  | Exit_long, Long { shares; entry_date; entry_price } ->
      let proceeds = shares *. sell_px in
      let trade =
        _record_long_close ~entry_date ~entry_price ~exit_date:date
          ~exit_price:sell_px
      in
      (cash +. proceeds, Flat, Some trade)
  | Enter_short, Flat ->
      let shares = cash /. sell_px in
      let proceeds = shares *. sell_px in
      ( cash +. proceeds,
        Short { shares; entry_date = date; entry_price = sell_px },
        None )
  | Exit_short, Short { shares; entry_date; entry_price } ->
      let cost = shares *. buy_px in
      let trade =
        _record_short_close ~entry_date ~entry_price ~exit_date:date
          ~exit_price:buy_px
      in
      (cash -. cost, Flat, Some trade)
  | _, _ ->
      (* Hold / mismatched action vs position — no-op. *)
      (cash, position, None)

let force_close_at_end ~position ~cash ~final_bar ~bid_ask_bps =
  let buy_px, sell_px =
    adjusted_prices ~bid_ask_bps ~close:final_bar.Types.Daily_price.close_price
  in
  match position with
  | Flat -> (cash, Flat, None)
  | Long { shares; entry_date; entry_price } ->
      let proceeds = shares *. sell_px in
      let trade =
        _record_long_close ~entry_date ~entry_price ~exit_date:final_bar.date
          ~exit_price:sell_px
      in
      (cash +. proceeds, Flat, Some trade)
  | Short { shares; entry_date; entry_price } ->
      let cost = shares *. buy_px in
      let trade =
        _record_short_close ~entry_date ~entry_price ~exit_date:final_bar.date
          ~exit_price:buy_px
      in
      (cash -. cost, Flat, Some trade)
