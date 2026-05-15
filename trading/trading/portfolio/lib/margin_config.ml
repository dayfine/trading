(* Margin accounting configuration — see [.mli] for full contract.

   The module exposes the parameters needed to model Reg-T-style short
   selling. Numeric defaults below are named constants so the magic-number
   linter is satisfied; downstream code should always read the parameters
   from [t], never hardcode them. *)

open Core

type t = {
  enabled : bool;
  initial_margin_pct : float;
  maintenance_margin_pct : float;
  short_borrow_fee_annual_pct : float;
}
[@@deriving show, eq, sexp]

let default_enabled = false
let default_initial_margin_pct = 0.50
let default_maintenance_margin_pct = 0.25
let default_short_borrow_fee_annual_pct = 0.005
let trading_days_per_year = 252.0

let default_config =
  {
    enabled = default_enabled;
    initial_margin_pct = default_initial_margin_pct;
    maintenance_margin_pct = default_maintenance_margin_pct;
    short_borrow_fee_annual_pct = default_short_borrow_fee_annual_pct;
  }

let total_collateral_factor (cfg : t) : float = 1.0 +. cfg.initial_margin_pct

let daily_borrow_rate (cfg : t) : float =
  cfg.short_borrow_fee_annual_pct /. trading_days_per_year
