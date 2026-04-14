(** Core backtest execution library.

    Runs the Weinstein strategy over the full universe for a given date range
    and returns the result (summary sexp, round trips, metrics, final value,
    filtered steps). Output-directory writing is separated from running so
    callers (CLI, scenario runner) can control where artefacts go, or skip
    writing entirely. *)

open Core

(** {1 Public types} *)

type result = {
  summary_sexp : Sexp.t;
      (** Human-readable summary sexp (run info + metrics) *)
  round_trips : Trading_simulation.Metrics.trade_metrics list;
      (** Closed-position trades extracted from the filtered steps *)
  metrics : Trading_simulation_types.Metric_types.metric_set;
      (** Full metric set computed by the simulator *)
  final_value : float;  (** Final portfolio value on the last trading day *)
  steps : Trading_simulation_types.Simulator_types.step_result list;
      (** Steps filtered to [start_date..end_date] on real trading days only *)
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
}

(** {1 Running a backtest} *)

val run_backtest :
  start_date:Date.t ->
  end_date:Date.t ->
  ?overrides:Sexp.t list ->
  unit ->
  result
(** Load universe / AD bars / sector map, build a fresh strategy, run the
    simulator from [start_date - warmup] to [end_date], filter to the requested
    range and to trading days only, and return the [result].

    [overrides] are partial config sexps deep-merged into the default config in
    order. Each must be a record sexp with fields matching
    [Weinstein_strategy.config]. Example:
    {[
    [
      Sexp.of_string "((initial_stop_buffer 1.08))";
      Sexp.of_string "((stage_config ((ma_period 40))))";
    ]
    ]} *)

(** {1 Writing artefacts} *)

val write_output_dir : output_dir:string -> result -> unit
(** Write [params.sexp], [summary.sexp], and [trades.csv] into [output_dir]. The
    directory must already exist. Equity curve is intentionally omitted (too
    large for routine runs). *)
