(** Test-only accessor functions for [Portfolio_risk] record types.

    Provides named getters for use with the [field] matcher, avoiding repeated
    [fun s -> s.field_name] lambdas in test assertions.

    These modules mirror the production types but live in test code only — zero
    production overhead. *)

open Portfolio_risk

module Snapshot : sig
  val total_value : portfolio_snapshot -> float
  val cash : portfolio_snapshot -> float
  val cash_pct : portfolio_snapshot -> float
  val long_exposure : portfolio_snapshot -> float
  val long_exposure_pct : portfolio_snapshot -> float
  val short_exposure : portfolio_snapshot -> float
  val position_count : portfolio_snapshot -> int
end

module Sizing : sig
  val shares : sizing_result -> int
  val position_value : sizing_result -> float
  val position_pct : sizing_result -> float
  val risk_amount : sizing_result -> float
end
