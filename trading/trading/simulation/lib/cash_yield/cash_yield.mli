(** Interest on uninvested cash (issue #3137, part 1).

    A backtest that charges idle cash 0 % is scored on a price-only basis that
    is biased toward full investment: drawdown credits cash for avoiding pain
    while return charges it nothing. Weinstein (Ch. 9) parks out-of-market cash
    in a money-market fund; this module prices that.

    {b Rate.} The gross annualised rate is either a constant or a dated series
    (the 3-month T-bill, FRED [DTB3]). The rate credited is
    [max 0 (gross_pct - fee_bp / 100)] — the fee stands in for the expense ratio
    of the fund the cash sits in (10 bp = SGOV/BIL class, 35 bp = a money-market
    fund).

    {b Day count.} ACT/360 simple daily: each calendar day credits
    [base * net_pct / 100 / 360], weekends and holidays included (a fund accrues
    them). [DTB3] is quoted on the bank-discount basis, which understates the
    investment yield; ACT/360 on the discount rate lands within a few bp of the
    bond-equivalent yield at T-bill levels (4 % discount: 4.06 % vs 4.10 %), so
    no further conversion is applied.

    {b Base.} Interest accrues on
    [max 0 (current_cash - long_margin_debit - short_proceeds)], where
    [short_proceeds] is each open short's [|quantity| * avg_cost]: borrowed cash
    and the proceeds of a short sale earn nothing (a retail account gets no
    short rebate). A negative base accrues nothing; financing charges on debit
    balances are priced elsewhere ([Portfolio_margin]). *)

open Core

(** Where the gross rate comes from. A strategy-config axis: [No_yield] is the
    exact pre-#3137 behaviour (no accrual at all); the strategy-config default
    is {!default_source}. *)
type source =
  | No_yield  (** No interest on cash (the pre-#3137 price-only basis). *)
  | Constant of float
      (** A flat annualised rate in percent ([4.0] = 4 %/yr). *)
  | Series of string
      (** Path to a dated rate CSV ([date,annualised_percent], see
          {!parse_series_csv}). A relative path resolves against the data
          directory ([TRADING_DATA_DIR]); the committed 3-month T-bill series is
          [macro/tbill_3m_dtb3.csv]. *)
[@@deriving sexp, eq, show]

val default_fee_bp : float
(** [10.0] bp/yr — an SGOV/BIL-class T-bill fund expense ratio. *)

val default_series_path : string
(** ["macro/tbill_3m_dtb3.csv"] — the committed FRED [DTB3] 3-month T-bill
    series (1954-01-04 onward), relative to the data directory. *)

val default_source : source
(** [Series default_series_path] — the strategy-config default since the #3137
    default-on flip (accounting realism, approved by the paired 26y
    implementation check in
    [dev/experiments/total-return-26y-2026-10-06/results-2026-10-07.md]). *)

type t
(** A resolved rate source net of its fee. *)

val constant : rate_pct:float -> fee_bp:float -> t
(** A flat gross rate of [rate_pct] %/yr less [fee_bp]. *)

val of_series : (Date.t * float) list -> fee_bp:float -> t Status.status_or
(** A dated series of gross annualised percent rates, in any order. Each rate
    holds from its date until the next published one (forward-fill across
    non-publication days). [Error] on an empty series. *)

val parse_series_csv : string -> (Date.t * float) list Status.status_or
(** Parse CSV text with rows [YYYY-MM-DD,rate]. A first line whose date does not
    parse is a header and is skipped; blank lines and rows whose value is empty
    or ["."] (FRED's missing-value marker) are skipped, so those days
    forward-fill. Any other malformed row is an [Error] naming its line. *)

val resolve :
  source -> fee_bp:float -> data_dir:string -> t option Status.status_or
(** [None] for [No_yield]; otherwise the resolved rate, loading a [Series] file
    from disk ([Error] when it cannot be read or parsed, or is empty). *)

val net_annual_pct : t -> Date.t -> float Status.status_or
(** The annualised percent rate credited on [date], net of the fee and floored
    at [0]. [Error] when [date] precedes a series' first observation — there is
    no silent zero before the data starts. *)

val period_rate : t -> from_:Date.t -> to_:Date.t -> float Status.status_or
(** Simple sum of the daily ACT/360 rates over the calendar days in
    [(from_, to_]] — the cash return between two marks, used as the per-period
    risk-free rate for an excess-return Sharpe. [0.0] when [to_ <= from_]. *)

val interest_base : Trading_portfolio.Portfolio.t -> float
(** The cash balance that earns interest (see the module doc), [>= 0]. *)

val accrue :
  t ->
  date:Date.t ->
  Trading_portfolio.Portfolio.t ->
  (Trading_portfolio.Portfolio.t * float) Status.status_or
(** Credit one calendar day's interest on [interest_base] to [current_cash].
    Returns the updated portfolio and the amount credited. *)

(** Per-run accrual state for the simulator: the rate, the first date that
    accrues (the measurement-window start, so warmup earns nothing) and the
    running total credited. One value per run; it is mutated by {!step}. *)
module Accrual : sig
  type rate := t
  type t

  val create : rate -> start_date:Date.t -> t
  (** Fresh state with a zero running total. *)

  val step :
    t option ->
    date:Date.t ->
    Trading_portfolio.Portfolio.t ->
    Trading_portfolio.Portfolio.t Status.status_or
  (** Accrue [date]'s interest when armed and [date >= start_date], adding the
      credit to the running total. [None] (or a date before [start_date])
      returns the portfolio unchanged. *)

  val total : t -> float
  (** Interest credited so far, in dollars. *)
end
