(** Returns-block metric computer (M5.2b).

    Produces the raw + extreme returns metrics from the portfolio-value sequence
    emitted by the simulator: total return, annualized volatility, annualized
    downside deviation, and best/worst calendar-bucketed returns (day, week,
    month, quarter, year).

    Pure: same step list → same output. *)

val computer :
  unit -> Trading_simulation_types.Simulator_types.any_metric_computer
(** Build a metric computer that emits the returns-block group:

    - [TotalReturnPct]
    - [VolatilityPctAnnualized]
    - [DownsideDeviationPctAnnualized]
    - [BestDayPct], [WorstDayPct]
    - [BestWeekPct], [WorstWeekPct]
    - [BestMonthPct], [WorstMonthPct]
    - [BestQuarterPct], [WorstQuarterPct]
    - [BestYearPct], [WorstYearPct]

    Calendar bucketing is by ISO calendar week (Mon–Sun), calendar month,
    calendar quarter (Q1=Jan–Mar, …, Q4=Oct–Dec), and calendar year. Cumulative
    bucket return is computed on the {b last} portfolio_value of each bucket
    relative to the {b last} portfolio_value of the previous bucket (i.e. the
    bucket's compounded change), which mirrors the standard "monthly returns"
    reporting convention. The first bucket's return is relative to the initial
    portfolio_value (= initial_cash). *)
