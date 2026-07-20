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
  short_borrow_rate_tiers : Short_margin_tiers.tier list; [@sexp.default []]
  short_maintenance_tiers : Short_margin_tiers.tier list; [@sexp.default []]
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
    short_borrow_rate_tiers = [];
    short_maintenance_tiers = [];
  }

let total_collateral_factor (cfg : t) : float = 1.0 +. cfg.initial_margin_pct

(* Annual borrow fee for a short marked at [price]: the price-tiered rate when
   [short_borrow_rate_tiers] is armed, else the flat
   [short_borrow_fee_annual_pct]. Empty table (the default) → flat fallback,
   so a disarmed config is bit-identical to pre-M3a. *)
let borrow_fee_annual_for_price (cfg : t) ~(price : float) : float =
  Short_margin_tiers.tier_value ~tiers:cfg.short_borrow_rate_tiers
    ~flat_fallback:cfg.short_borrow_fee_annual_pct ~price

let daily_borrow_rate (cfg : t) : float =
  cfg.short_borrow_fee_annual_pct /. trading_days_per_year

let daily_borrow_rate_for_price (cfg : t) ~(price : float) : float =
  borrow_fee_annual_for_price cfg ~price /. trading_days_per_year

(* Maintenance equity-ratio threshold for a short marked at [price]: the
   price-tiered value when [short_maintenance_tiers] is armed, else the flat
   [maintenance_margin_pct]. Empty table (the default) → flat fallback. *)
let maintenance_pct_for_price (cfg : t) ~(price : float) : float =
  Short_margin_tiers.tier_value ~tiers:cfg.short_maintenance_tiers
    ~flat_fallback:cfg.maintenance_margin_pct ~price
