(** Buy-and-Hold benchmark strategy — single-symbol baseline for comparing other
    strategies against a passive index-ETF position.

    On the first market-close call where price data is available for the
    configured symbol, this strategy emits exactly one [CreateEntering]
    transition that buys [floor(portfolio.cash / close_price)] shares with all
    available cash. Every subsequent call returns zero transitions: it never
    sells, rebalances, or adjusts.

    The intended primary use is benchmarking. Every Weinstein-style backtest can
    be paired with a BAH-SPY run on the same window and same starting cash; if
    the active strategy doesn't beat BAH-SPY, the active strategy isn't adding
    alpha. The same property doubles as an accounting check — BAH-SPY's final
    equity should track SPY's price-only return very closely (modulo dividend
    treatment in the data feed; see {!default_symbol} notes).

    {1 Sizing}

    All-cash sizing — [floor(cash / close_price)] — is deliberately distinct
    from the fixed-share sizing in {!Buy_and_hold_strategy}. The latter expects
    the caller to know the share count up front; the benchmark interpretation is
    "given $X starting cash, how many shares of SPY can I buy on day 1?". Using
    cash as the input lets the same module be reused across scenarios with
    different starting capital without rederiving share counts.

    The strategy reads [portfolio.cash] at the moment of entry. If the engine
    has already allocated cash to other commitments (it shouldn't on day 1 when
    this strategy runs alone), only the available cash is sized against.

    {1 Symbol convention}

    The default symbol is the bare ticker [SPY], matching the on-disk data
    layout under [data/S/Y/SPY/]. Callers using EODHD-suffixed symbols (e.g.
    [SPY.US]) should override [config.symbol] explicitly — the data adapter will
    then need an entry for that key. *)

type config = {
  symbol : string;
      (** Ticker to buy and hold. Default {!default_symbol}. The strategy does
          nothing if [get_price symbol] returns [None] on a given day, so a
          symbol with no data simply produces a never-entering benchmark. *)
}
[@@deriving show, eq]

val name : string
(** Human-readable strategy name, [BuyAndHoldBenchmark]. *)

val default_symbol : string
(** [SPY] — the SPDR S&P 500 ETF, used as the default benchmark instrument. Bare
    ticker (no exchange suffix), matching the repository's CSV-on-disk layout.
*)

val default_config : config
(** [{ symbol = default_symbol }]. *)

val make : config -> (module Strategy_interface.STRATEGY)
(** Create a strategy instance implementing {!Strategy_interface.STRATEGY}. The
    configuration is captured in the closure; the strategy itself is stateless
    beyond what the caller-managed [portfolio.positions] map carries. *)
