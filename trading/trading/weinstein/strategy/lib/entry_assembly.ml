open Weinstein_strategy_config

let assemble ~config ~bar_reader ~current_date (screen_result : Screener.result)
    =
  let combined =
    Short_side_gate.combine ~enable_short_side:config.enable_short_side
      ~short_min_price:config.short_min_price
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
