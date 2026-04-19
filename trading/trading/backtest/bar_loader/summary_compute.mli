(** Pure compute helpers for the Summary tier of {!Bar_loader}.

    A [Summary.t] is a handful of indicator scalars (30-week MA, ATR-14, RS
    line, stage heuristic) derived from a bounded tail of daily bars. Keeping
    the compute logic in its own module means the math is unit-testable without
    a [Price_cache] / CSV round-trip, and the [Bar_loader] integration layer
    stays focused on tier bookkeeping.

    All functions in this module are pure: same inputs always produce the same
    output. Callers provide already-loaded daily bars; loading is the
    responsibility of {!Bar_loader}. *)

open Core

(** {1 Configuration} *)

type config = {
  ma_weeks : int;  (** Weeks in the Weinstein MA. Default: 30. *)
  atr_days : int;  (** Lookback days for ATR. Default: 14. *)
  rs_ma_period : int;
      (** Mansfield RS zero-line MA length in aligned bars. Default: 52 (~one
          year weekly, or ~52 trading days if daily). *)
  tail_days : int;
      (** Upper bound on the daily-bar tail the Summary loader fetches per
          symbol. Must be large enough to cover the longest indicator window
          plus warmup. Default: 250 (~ [ma_weeks] × 7 + ATR warmup). *)
}
[@@deriving sexp, show, eq]

val default_config : config
(** Sensible defaults for Weinstein-style analysis:
    [{ ma_weeks = 30; atr_days = 14; rs_ma_period = 52; tail_days = 250 }]. *)

(** {1 Indicator primitives}

    Each helper returns [None] when there are not enough bars to produce a valid
    result — summary loaders treat [None] as "insufficient history; leave this
    symbol at its current tier". *)

val ma_30w : config:config -> Types.Daily_price.t list -> float option
(** [ma_30w ~config bars] aggregates [bars] to weekly (last-bar-of-week) and
    returns the simple moving average of the last [config.ma_weeks] weekly
    closes. Returns [None] when there are fewer than [config.ma_weeks] weekly
    bars available. *)

val atr_14 : config:config -> Types.Daily_price.t list -> float option
(** [atr_14 ~config bars] returns the Average True Range over the most recent
    [config.atr_days] bars. True range for bar [i] is
    [max (high - low, |high - prev_close|, |low - prev_close|)]. The first bar
    has no prior close and is skipped. Returns [None] when there are fewer than
    [config.atr_days + 1] bars. *)

val rs_line :
  config:config ->
  stock_bars:Types.Daily_price.t list ->
  benchmark_bars:Types.Daily_price.t list ->
  float option
(** [rs_line ~config ~stock_bars ~benchmark_bars] returns the latest Mansfield
    normalized RS value for the stock against the benchmark, or [None] when
    there are fewer than [config.rs_ma_period] aligned bars. The value is
    [raw_rs / MA(raw_rs)] — values above 1.0 mean the stock is outperforming its
    own recent baseline. *)

val stage_heuristic :
  config:config -> Types.Daily_price.t list -> Weinstein_types.stage option
(** [stage_heuristic ~config bars] runs the {!Stage.classify} one-shot
    classifier on weekly-aggregated bars and returns the resulting stage.
    Returns [None] when aggregation yields fewer than [config.ma_weeks] weekly
    bars (i.e. {!Stage.classify} would emit a degenerate Stage1 placeholder — we
    surface that as "no heuristic available" instead). *)

(** {1 Summary composition} *)

type summary_values = {
  ma_30w : float;
  atr_14 : float;
  rs_line : float;
  stage : Weinstein_types.stage;
  as_of : Date.t;
}
[@@deriving sexp, show, eq]
(** Indicator scalars produced by {!compute_values}. Mirrors the fields of
    [Bar_loader.Summary.t] minus the [symbol] key. *)

val compute_values :
  config:config ->
  stock_bars:Types.Daily_price.t list ->
  benchmark_bars:Types.Daily_price.t list ->
  as_of:Date.t ->
  summary_values option
(** [compute_values ~config ~stock_bars ~benchmark_bars ~as_of] runs all four
    helpers and assembles a {!summary_values}. Returns [None] when any helper
    returns [None] — the caller should leave the symbol at Metadata tier in that
    case. *)
