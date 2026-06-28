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
  Entry_liquidity_gate.apply ~config:config.liquidity_config ~bar_reader
    ~current_date combined
