(** After-tax equity-path model.

    Pure. Given per-year realized ST/LT gains (from closed trades) and the
    pre-tax year-end equity path, it simulates an after-tax capital path where
    each year's tax bill is paid out of the compounding capital.

    Model rules (Phase 1, pinned in issue #2006):
    - Realization basis by exit-year; open positions defer (never taxed here).
    - Year-end payment (no April deferral).
    - Losses are never deducted in-year — under [carryforward] they accumulate a
      pool that offsets future gains, ST gains first (taxpayer-favourable).
    - The after-tax path scales each year's tax by the after-tax/pre-tax capital
      ratio [at_start / pt_start] — a smaller portfolio realizes proportionally
      smaller gains, so pays proportionally less tax. *)

type year_row = {
  year : int;
  pretax_end : float;  (** pre-tax year-end equity (from equity_curve) *)
  aftertax_end : float;  (** simulated after-tax year-end equity *)
  st_gain : float;  (** net short-term realized this year (may be < 0) *)
  lt_gain : float;  (** net long-term realized this year (may be < 0) *)
  raw_tax : float;
      (** tax on the pre-tax gains (before capital-ratio scaling) *)
  paid_tax : float;  (** tax actually paid from after-tax capital *)
  carryforward_end : float;  (** loss carryforward pool at year end *)
}
[@@deriving sexp, equal]
(** One calendar year of the simulated path. *)

type result = {
  config : Tax_config.t;
  rows : year_row list;
  pretax_final : float;
  aftertax_final : float;
  pretax_cagr : float;
  aftertax_cagr : float;
  total_tax_paid : float;
  total_realized_pnl : float;
  final_unrealized : float;
      (** terminal equity not attributable to closed trades — deferred, untaxed
      *)
}
[@@deriving sexp]

val year_tax :
  st_rate:float ->
  lt_rate:float ->
  carryforward:bool ->
  cf:float ->
  st:float ->
  lt:float ->
  float * float
(** Compute the raw (pre-scaling) tax for one year and the updated carryforward
    pool. Exposed for unit testing the carryforward / offset-ordering rules.
    Returns [(raw_tax, carryforward_end)]. *)

val simulate : Tax_config.t -> Tax_types.run_data -> result
(** Simulate the after-tax path over [run_data] under [config]. *)
