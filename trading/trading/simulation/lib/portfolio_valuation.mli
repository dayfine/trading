(** Portfolio mark-to-market valuation with multi-tier price-resolution
    fallback.

    The simulator drives daily NAV via {!compute}, which routes each held
    position through a four-tier resolution chain:

    + [today_bars] (the current step's bar set, authoritative when present),
    + [Market_data_adapter.get_previous_bar] (adapter forward-fill),
    + [last_known_prices] cache (this run's last-resolved close, populated on
      every successful resolution above),
    + the position's avg cost basis (zero-unrealized assumption — last resort
      when no market price has ever been seen for the symbol).

    Tier (4) increments [valuation_failure_count] so the operator can audit the
    fallback rate at end-of-run. The earlier silent collapse to
    [portfolio.current_cash] (which corrupted [equity_curve.csv]
    daily-derivative metrics on runs with delisting / dataset edges) survives
    only as defense-in-depth: with the cache + avg-cost chain in place, every
    held position is now priced, so [Calculations.portfolio_value] should always
    return [Ok]. See {!compute} for the full contract. *)

open Core

val compute :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  date:Date.t ->
  portfolio:Trading_portfolio.Portfolio.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  last_known_prices:float String.Table.t ->
  valuation_failure_count:int ref ->
  float
(** [compute ~adapter ~date ~portfolio ~today_bars ~last_known_prices
     ~valuation_failure_count] returns the portfolio's total mark-to-market
    value (cash + position market values) on [date].

    Each held position is priced via the four-tier chain documented at the top
    of this module. The cache is updated on every successful resolution so
    subsequent steps within the same run benefit from carry-forward.
    [valuation_failure_count] is incremented exactly once per (symbol, step)
    pair that fell through to the avg-cost last-resort.

    Always returns a finite value. The legacy cash-only fallback (when
    [Calculations.portfolio_value] errors despite the chain providing a price
    for every held position) is preserved as defense-in-depth and likewise
    increments [valuation_failure_count]. *)
