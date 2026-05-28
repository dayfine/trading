(** Stripped-down per-symbol Weinstein stage backtest.

    Loads daily bars for one symbol, weeklyises them, walks the weekly bar
    series chronologically, and trades on stage transitions per {!Stage_signal}.
    NO portfolio mechanics — single-symbol, 100%-of-cash sizing, no
    diversification, no sector caps, no screener cascade. The point of the
    diagnostic is to isolate the stage-transition signal from every
    portfolio-level confounding mechanism.

    Pure functions (modulo the CSV read). Reuses {!Stage.classify} as-is — same
    stage classifier the production Weinstein system uses, so the diagnostic
    measures the same definition. *)

open Core

type result = {
  symbol : string;
  variant : Stage_signal.variant;
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  final_equity : float;
  strategy_cagr : float;
      (** Annualised compound return. 0.0 on empty input or terminal-zero
          equity. *)
  strategy_sharpe : float;
      (** Annualised Sharpe on weekly returns (scaled by sqrt(52)). *)
  strategy_max_dd : float;
      (** Peak-to-trough max drawdown, expressed as a negative fraction (e.g.
          -0.34 for 34% drawdown). *)
  bah_cagr : float;
      (** Annualised buy-and-hold CAGR over the same window — bought on the
          first available weekly bar's close and held to the last. *)
  bah_max_dd : float;
  num_long_entries : int;
  num_short_entries : int;
  pct_time_long : float;
      (** Fraction of weekly bars during which the strategy held a long
          position. 0.0 to 1.0. *)
  pct_time_short : float;  (** Long-short only; 0.0 for long-only runs. *)
  avg_holding_days : float;
      (** Average calendar days held across all completed long-or-short
          round-trips. 0.0 if no trades. *)
  trades : Walk_step.trade list;
      (** All round-trips in chronological order (entry order), including a
          forced-close trade for any position open at the window's end. *)
  year_end_equity : (int * float) list;
      (** Year-end equity samples (last weekly bar of each calendar year present
          in the run window). For Section 4 of the report. *)
}
[@@deriving show]
(** End-of-run summary for one symbol × one variant. All metrics computed from
    the simulated weekly equity curve. *)

val run :
  data_dir:Fpath.t ->
  symbol:string ->
  start_date:Date.t ->
  end_date:Date.t ->
  initial_cash:float ->
  variant:Stage_signal.variant ->
  ?bid_ask_bps:float ->
  unit ->
  (result, Status.t) Result.t
(** [run ~data_dir ~symbol ~start_date ~end_date ~initial_cash ~variant
     ?bid_ask_bps ()] backtests the minimal stage strategy on [symbol].

    @param data_dir
      Repo data root (shard layout, e.g. [/workspaces/trading-1/data/]).
    @param symbol Bare ticker (e.g. ["SPY"], ["XLK"]).
    @param start_date
      Inclusive backtest start. Bars before this date are still loaded and used
      for warmup (the stage classifier needs at least [ma_period] = 30 weeks of
      prior data; [Csv_storage.get] returns the full series and we then truncate
      the simulation to bars on or after [start_date]).
    @param end_date Inclusive backtest end.
    @param initial_cash Starting cash; entries deploy all of it.
    @param variant {!Stage_signal.Long_only} or {!Stage_signal.Long_short}.
    @param bid_ask_bps
      One-sided bid-ask spread cost in basis points. Default 0.5 bps. Buys pay
      [price * (1 + bps/10000)]; sells receive [price * (1 - bps/10000)];
      symmetric for short cover/short sell.

    Returns [Error] if the CSV read fails or the symbol has fewer weekly bars
    than the classifier needs. Returns [Ok result] even when the run produced no
    trades (e.g. the symbol stayed in Stage 1 the whole time) — caller checks
    [result.num_long_entries + result.num_short_entries]. *)
