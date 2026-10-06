open Weinstein_strategy_config

(* #3131: the price [short_min_price] gates. Under
   [short_min_price_on_order_price] it is the price the short ticket is placed
   at — the same [Entry_audit_helpers.effective_entry_price] the entry walk
   installs — so a name already collapsed below the floor at decision time is
   not admitted on a stale level. *)
let _short_price_of ~config ~bar_reader ~current_date =
  if config.short_min_price_on_order_price then
    let trigger_at_suggested =
      config.sim_entry_trigger_at_suggested && config.enable_sim_entry_stoplimit
    in
    Entry_audit_helpers.effective_entry_price ~trigger_at_suggested ~bar_reader
      ~current_date
  else Short_min_price_gate.suggested_entry_price

let assemble ~config ~bar_reader ~current_date (screen_result : Screener.result)
    =
  let combined =
    Short_side_gate.combine ~enable_short_side:config.enable_short_side
      ~short_min_price:config.short_min_price
      ~short_price_of:(_short_price_of ~config ~bar_reader ~current_date)
      ~buy_candidates:screen_result.Screener.buy_candidates
      ~short_candidates:screen_result.Screener.short_candidates
  in
  let combined =
    Declining_ma_gate.filter ~reject:config.reject_declining_ma_long_entry
      combined
  in
  let combined =
    Entry_liquidity_gate.apply ~config:config.liquidity_config ~bar_reader
      ~current_date combined
  in
  let combined =
    Short_borrow_gate.apply ~min_dollar_adv:config.short_borrow_min_dollar_adv
      ~liquidity_config:config.liquidity_config ~bar_reader ~current_date
      combined
  in
  let combined =
    Entry_recency_gate.apply ~max_bar_age_days:config.entry_max_bar_age_days
      ~bar_reader ~current_date combined
  in
  (* Unconditional and last (#2693): the delisting marker is data, not a
     mechanism, so no config field gates it. A no-op on any warehouse whose
     manifest carries no [active_through]. *)
  Delisted_entry_gate.apply ~bar_reader ~current_date combined
