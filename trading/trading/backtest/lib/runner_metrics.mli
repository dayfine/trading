open Core

val recompute_in_window_step_metrics :
  ?cash_yield:Trading_simulation_cash_yield.Cash_yield.t ->
  steps_in_range:Trading_simulation_types.Simulator_types.step_result list ->
  start_date:Date.t ->
  end_date:Date.t ->
  unit ->
  Trading_simulation_types.Metric_types.metric_set
(** Re-run [SharpeRatio], [MaxDrawdown], and [CAGR] computers on the in-window
    step list only. The simulator runs from [warmup_start] so its published
    step-based metrics include the warmup window; this call restores them to the
    measurement window. With [cash_yield] (#3137) the Sharpe is on excess return
    over that cash rate; without it, over 0 (unchanged). *)

val recompute_calmar_ratio :
  base_metrics:Trading_simulation_types.Metric_types.metric_set ->
  Trading_simulation_types.Metric_types.metric_set
(** Recompute [CalmarRatio = CAGR / MaxDrawdown] from [base_metrics] so the
    derived metric stays consistent with the already-overlaid CAGR and
    MaxDrawdown components. *)

val align_summary_metrics :
  ?cash_yield:Trading_simulation_cash_yield.Cash_yield.t ->
  sim_result:Trading_simulation_types.Simulator_types.run_result ->
  round_trips:Trading_simulation.Metrics.trade_metrics list ->
  steps_in_range:Trading_simulation_types.Simulator_types.step_result list ->
  start_date:Date.t ->
  end_date:Date.t ->
  unit ->
  Trading_simulation_types.Metric_types.metric_set
(** Three-stage overlay: replace round-trip metrics from [round_trips], replace
    step-based metrics from [steps_in_range], then recompute [CalmarRatio].
    Restores the invariant that published metrics describe the measurement
    window [start_date..end_date] only, not the warmup window the simulator ran
    from. [cash_yield] is passed to the Sharpe recompute (#3137); the
    simulator's [CashInterestTotal], when present, passes through unchanged. *)
