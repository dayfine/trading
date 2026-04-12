(** Test-only accessor functions for [Portfolio_risk] record types.

    Used with the [field] matcher to avoid repeating [fun s -> s.field_name]
    lambdas in test assertions. Only defines accessors for fields that are
    actually asserted on in tests. *)

open Portfolio_risk

module Snapshot = struct
  let total_value (s : portfolio_snapshot) = s.total_value
  let cash (s : portfolio_snapshot) = s.cash
  let cash_pct (s : portfolio_snapshot) = s.cash_pct
  let long_exposure (s : portfolio_snapshot) = s.long_exposure
  let long_exposure_pct (s : portfolio_snapshot) = s.long_exposure_pct
  let short_exposure (s : portfolio_snapshot) = s.short_exposure
  let position_count (s : portfolio_snapshot) = s.position_count
end

module Sizing = struct
  let shares (r : sizing_result) = r.shares
  let position_value (r : sizing_result) = r.position_value
  let position_pct (r : sizing_result) = r.position_pct
  let risk_amount (r : sizing_result) = r.risk_amount
end
