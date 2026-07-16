open Core
module Margin_config = Trading_portfolio.Margin_config

(* #1965 exposure term: infinity when disabled ([<= 0.0]), else a fraction of
   equity. Byte-identical to the pre-M1 inline computation in
   [Screening_notional.make_entry_walk_state]. *)
let _exposure_term ~max_long_exposure_pct_entry ~equity =
  if Float.( <= ) max_long_exposure_pct_entry 0.0 then Float.infinity
  else equity *. max_long_exposure_pct_entry

(* Buying-power term. A cash account (req >= 1.0) imposes no explicit equity
   ceiling — the reachable [equity] ceiling is the explicit
   [max_long_exposure_pct_entry = 1.0] opt-in, and the pre-M1 default bounded new
   long funding only by the implicit available-cash gate. Only a fractional req
   (0 < req < 1) opens leverage headroom [equity / req]. req <= 0 is a guard
   (treated as "no ceiling"). *)
let _margin_term ~initial_long_margin_req ~equity =
  if Float.( >= ) initial_long_margin_req 1.0 then Float.infinity
  else if Float.( <= ) initial_long_margin_req 0.0 then Float.infinity
  else equity /. initial_long_margin_req

let long_notional_ceiling ~max_long_exposure_pct_entry ~initial_long_margin_req
    ~equity =
  Float.min
    (_exposure_term ~max_long_exposure_pct_entry ~equity)
    (_margin_term ~initial_long_margin_req ~equity)

let daily_long_margin_rate ~annual_pct =
  if Float.( <= ) annual_pct 0.0 then 0.0
  else annual_pct /. Margin_config.trading_days_per_year

let long_margin_interest_charge ~rate_annual_pct ~debit_balance =
  Float.max 0.0 debit_balance
  *. daily_long_margin_rate ~annual_pct:rate_annual_pct
