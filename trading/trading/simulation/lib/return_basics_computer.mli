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

    Calendar bucketing is by ISO 8601 calendar week (Mon–Sun, keyed by the
    [(week_numbering_year, week_number)] pair from [Core.Date], so a date in
    early January or late December is grouped with its true ISO week — e.g.
    2024-12-30 and 2025-01-02 share bucket 2025-W01), calendar month, calendar
    quarter (Q1=Jan–Mar, …, Q4=Oct–Dec), and calendar year. Cumulative bucket
    return is computed on the {b last} portfolio_value of each bucket relative
    to the {b last} portfolio_value of the previous bucket (i.e. the bucket's
    compounded change), which mirrors the standard "monthly returns" reporting
    convention. The first bucket's return is relative to the initial
    portfolio_value (= initial_cash). *)
