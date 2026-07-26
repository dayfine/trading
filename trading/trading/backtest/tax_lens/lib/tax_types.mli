(** Shared value types for the after-tax performance lens.

    The lens is a pure post-run report layer over an existing scenario output
    directory ([trades.csv] + [equity_curve.csv]). It performs no simulation and
    touches no core trading module. *)

type realized_trade = {
  symbol : string;
  exit_year : int;  (** calendar year of [exit_date] — the realization year *)
  days_held : int;  (** holding period; [>= lt_days] qualifies for LT rates *)
  pnl : float;  (** realized dollar P&L ([pnl_dollars] column) *)
  side : string;  (** "LONG" / "SHORT" — carried for reporting only *)
}
[@@deriving sexp, equal]
(** One closed round-trip trade, projected from a [trades.csv] row. Open
    positions are intentionally excluded: under the realization basis their
    unrealized gains defer to a future (post-run) year and are never taxed. *)

type run_data = {
  trades : realized_trade list;
  equity_year_ends : (int * float) list;
      (** [(year, year-end portfolio value)] ascending by year, one entry per
          calendar year present in [equity_curve.csv]. *)
  initial_capital : float;  (** first equity-curve value *)
  span_years : float;  (** first→last equity date, in years (for CAGR) *)
}
[@@deriving sexp]
(** Everything the tax model needs from one scenario output directory. *)
