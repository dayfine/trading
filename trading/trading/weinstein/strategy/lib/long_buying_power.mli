(** Long-side buying-power model (levered long-short realism, M1a).

    Pure numeric primitives that generalize the #1965 entry-denominated
    long-exposure cap into a buying-power ceiling, plus the priced
    margin-interest convention for debit balances. No
    [Weinstein_strategy_config] dependency — the caller passes the scalar knobs
    — so the math is independently pinnable.

    {b Estimand.} The ceiling bounds aggregate {e entry-price-denominated}
    committed long notional (the same basis as
    {!Screening_notional.initial_long_notional} and
    {!Weinstein_strategy_config.max_long_exposure_pct_entry}), NOT marked value:
    marked exposure above NAV from unrealized appreciation of held winners is
    legitimate leverage-free growth and must not be capped.

    {b Default-off invariant (experiment-flag-discipline R1).} At the config
    defaults ([max_long_exposure_pct_entry = 0.0],
    [initial_long_margin_req = 1.0], [long_margin_rate_annual_pct = 0.0]) every
    function here is the pre-M1 no-op: {!long_notional_ceiling} returns
    [Float.infinity] (no explicit ceiling) and {!long_margin_interest_charge}
    returns [0.0]. Merging M1a changes no backtest result.

    {b Scope (M1a).} This module is the buying-power + interest {e math}. The
    per-tick simulator accrual of {!long_margin_interest_charge} and the
    entry-walk cash-gate relaxation that actually creates a positive debit
    balance (funding longs beyond available cash up to the ceiling) are M1b —
    until then the leverage headroom of a fractional [initial_long_margin_req]
    and the interest are inert (the implicit available-cash gate binds first, so
    the debit stays [0.0]).

    Authority: [dev/plans/levered-longshort-margin-realism-2026-07-14.md] §M1;
    [dev/plans/margin-m1-buying-power-2026-07-16.md]. *)

val long_notional_ceiling :
  max_long_exposure_pct_entry:float ->
  initial_long_margin_req:float ->
  equity:float ->
  float
(** Combined ceiling on aggregate entry-price-denominated long notional, the
    generalization of the #1965 cap: [min exposure_term margin_term].

    - [exposure_term]: the #1965 term, unchanged. [Float.infinity] when
      [max_long_exposure_pct_entry <= 0.0] (default no-op); else
      [max_long_exposure_pct_entry *. equity].
    - [margin_term]: the buying-power term. [Float.infinity] when
      [initial_long_margin_req >= 1.0] (a cash account / Reg-T 100% requirement
      imposes {e no explicit equity ceiling} — the pre-M1 behaviour bounded new
      long funding only by the implicit available-cash gate, and the reachable
      [equity] ceiling is the explicit [max_long_exposure_pct_entry = 1.0]
      opt-in, not the default). Also [Float.infinity] as a guard when
      [initial_long_margin_req <= 0.0]. Else ([0.0 < req < 1.0], leverage opted
      in) [equity /. initial_long_margin_req] (e.g. [req = 0.5] →
      [2.0 *. equity] of buying power).

    At the defaults both terms are [Float.infinity], so the ceiling is
    [Float.infinity] (R1). E-capped (#1965: [max_long_exposure_pct_entry = 1.0],
    [req = 1.0]) yields [min equity Float.infinity = equity], preserving that
    config exactly. *)

val daily_long_margin_rate : annual_pct:float -> float
(** Per-trading-day long-margin interest rate:
    [annual_pct /. Trading_portfolio.Margin_config.trading_days_per_year] (252),
    the same day-count convention as the short borrow fee. [0.0] when
    [annual_pct <= 0.0]. *)

val long_margin_interest_charge :
  rate_annual_pct:float -> debit_balance:float -> float
(** One trading day of interest on a long-margin debit balance:
    [(Float.max 0.0 debit_balance) *. daily_long_margin_rate
     ~annual_pct:rate_annual_pct].

    [debit_balance] is the borrowed cash (positive = a debit; a credit/zero
    balance is charged nothing). Returns [0.0] when [rate_annual_pct <= 0.0]
    (default no-op) or when [debit_balance <= 0.0]. Prices the old-Run-E "free
    leverage" so a levered long book carries a real financing cost. *)
