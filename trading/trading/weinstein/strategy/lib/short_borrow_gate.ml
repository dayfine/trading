open Core

let _short_has_borrow ~min_dollar_adv ~dollar_adv_for
    (c : Screener.scored_candidate) =
  match c.side with
  | Trading_base.Types.Long -> true (* borrow is a short-only concern *)
  | Trading_base.Types.Short -> (
      match dollar_adv_for c.Screener.ticker with
      | None -> true (* no reading -> never drop *)
      | Some adv -> Float.( >= ) adv min_dollar_adv)

let filter ~min_dollar_adv ~dollar_adv_for
    (candidates : Screener.scored_candidate list) =
  if Float.( <= ) min_dollar_adv 0.0 then candidates
  else
    List.filter candidates
      ~f:(_short_has_borrow ~min_dollar_adv ~dollar_adv_for)

let apply ~min_dollar_adv ~lookback_days ~bar_reader ~current_date candidates =
  if Float.( <= ) min_dollar_adv 0.0 then candidates
  else
    let dollar_adv_for ticker =
      Liquidity_metric.dollar_adv ~lookback_days
        (Bar_reader.daily_bars_for bar_reader ~symbol:ticker ~as_of:current_date)
    in
    filter ~min_dollar_adv ~dollar_adv_for candidates
