open Types

(** Mansfield Relative Strength indicator.

    Computes how a stock's price ratio vs a benchmark index has moved relative
    to its own historical average — the "zero-line" normalisation from Stan
    Weinstein's method.

    Formula:
    + Raw RS: [price / benchmark_price] at each aligned date.
    + MA of raw RS over [rs_ma_period] bars (the Mansfield zero line).
    + Normalized RS: [raw_rs / MA(raw_rs)]. Values above 1.0 indicate the stock
      is in "positive territory" (outperforming relative to its own recent
      history).

    All functions are pure. *)

type config = { rs_ma_period : int }
(** Computation parameters. [rs_ma_period]: number of bars for the zero-line MA.
    Default: 52 (weekly bars ≈ one year). *)

val default_config : config
(** Sensible defaults: [rs_ma_period = 52]. *)

type raw_rs = {
  date : Core.Date.t;
  rs_value : float;
      (** Ratio of stock adjusted-close to benchmark adjusted-close on [date].
      *)
  rs_normalized : float;
      (** [rs_value / MA(rs_value)] over [rs_ma_period] bars. A value above 1.0
          means the stock is outperforming relative to its own recent RS
          baseline. *)
}
(** One data point in the normalized RS series. *)

val analyze :
  config:config ->
  stock_bars:Daily_price.t list ->
  benchmark_bars:Daily_price.t list ->
  raw_rs list option
(** [analyze ~config ~stock_bars ~benchmark_bars] computes the full normalized
    RS series.

    @param stock_bars Adjusted-close bars for the stock, sorted chronologically.
    @param benchmark_bars
      Adjusted-close bars for the benchmark index (e.g., S&P 500), sorted
      chronologically.

    Bars are aligned on date: only dates present in both series are used. This
    handles stocks with different history lengths or missing data without error.

    Returns [None] when there are fewer than [rs_ma_period] aligned bars — not
    enough history for even one normalized RS value.

    Returns the history in chronological order (oldest first).

    Pure function. *)
