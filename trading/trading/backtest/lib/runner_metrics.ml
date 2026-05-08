open Core
open Trading_simulation

(** The simulator runs from [warmup_start] (not [start_date]) so all three of
    its metric flavors (round-trip, step-based, and derived) include the warmup
    window. The three functions below restore the invariant that the published
    metrics describe the measurement window only. *)

let initial_cash = 1_000_000.0
let commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(** Sentinel year used when constructing a dummy [config] for metric re-runs
    where the date range is irrelevant (e.g. [recompute_calmar_ratio]). Year
    2000 is safely before any real run date. *)
let _empty_date_sentinel_year = 2000

(** Re-run the step-based metric computers ([SharpeRatio], [MaxDrawdown],
    [CAGR]) on the in-window step list with a config whose [start_date] is the
    actual run start (not the warmup_start the simulator was created with). The
    simulator computed these metrics across [warmup_start..end_date], which
    folds the warmup window's drawdown, return volatility, and total return into
    the published values; this overlay restores the metrics' values to "what
    happened during the measurement window only". *)
let recompute_in_window_step_metrics ~steps_in_range ~start_date ~end_date =
  let config : Trading_simulation_types.Simulator_types.config =
    {
      start_date;
      end_date;
      initial_cash;
      commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let computers =
    [
      Metric_computers.sharpe_ratio_computer ();
      Metric_computers.max_drawdown_computer ();
      Metric_computers.cagr_computer ();
    ]
  in
  List.fold computers ~init:Trading_simulation_types.Metric_types.empty
    ~f:(fun acc c ->
      Trading_simulation_types.Metric_types.merge acc
        (c.run ~config ~steps:steps_in_range))

(** Recompute [CalmarRatio = CAGR / MaxDrawdown] from already-overlaid
    [base_metrics]. The simulator emits [CalmarRatio] from the
    [calmar_ratio_derived] computer using its own warmup-inclusive CAGR /
    MaxDrawdown; once the overlay has replaced those with in-window values, the
    published [CalmarRatio] must follow or the ratio is inconsistent with its
    components. *)
let recompute_calmar_ratio ~base_metrics =
  let dummy_config : Trading_simulation_types.Simulator_types.config =
    {
      start_date =
        Date.create_exn ~y:_empty_date_sentinel_year ~m:Month.Jan ~d:1;
      end_date = Date.create_exn ~y:_empty_date_sentinel_year ~m:Month.Jan ~d:1;
      initial_cash;
      commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  Metric_computers.calmar_ratio_derived.compute ~config:dummy_config
    ~base_metrics

(** Three-stage overlay applied to the simulator's metric set:

    1. Replace round-trip-derived metrics ([TotalPnl], [AvgHoldingDays],
    [WinCount], [LossCount], [WinRate], [ProfitFactor]) with values computed
    from the runner's range-filtered [round_trips].

    2. Replace step-based metrics ([SharpeRatio], [MaxDrawdown], [CAGR]) with
    values recomputed on [steps_in_range] (the in-window step list only).

    3. Recompute [CalmarRatio] from the overlaid CAGR / MaxDrawdown so the
    derived metric stays consistent with its components. *)
let align_summary_metrics ~sim_result ~round_trips ~steps_in_range ~start_date
    ~end_date =
  let merge = Trading_simulation_types.Metric_types.merge in
  let after_round_trips =
    merge sim_result.Trading_simulation_types.Simulator_types.metrics
      (Metrics.compute_round_trip_metric_set round_trips)
  in
  let after_step =
    merge after_round_trips
      (recompute_in_window_step_metrics ~steps_in_range ~start_date ~end_date)
  in
  merge after_step (recompute_calmar_ratio ~base_metrics:after_step)
