(** Time series utilities for simulation

    This module provides time period abstraction for the simulator,
    delegating to the proven time period conversion logic in analysis/.

    {1 Overview}

    The time_series module defines cadence types (Daily, Weekly, Monthly)
    and provides conversion functions that delegate to the
    analysis/technical/indicators/time_period module.

    {1 Design Rationale}

    This is a thin wrapper that:
    - Provides type-safe cadence abstraction
    - Delegates actual conversion to proven Conversion module
    - Centralizes time period logic for simulation layer
*)

open Core

type cadence =
  | Daily
  | Weekly
  | Monthly
[@@deriving show, eq]
(** Time period for indicator computation *)

val convert_cadence :
  Types.Daily_price.t list ->
  cadence:cadence ->
  as_of_date:Date.t option ->
  Types.Daily_price.t list
(** Convert daily prices to specified cadence.

    For Daily cadence: Returns prices unchanged.
    For Weekly/Monthly: Delegates to Time_period.Conversion module.

    @param prices Daily price data in chronological order
    @param cadence Target time period (Daily, Weekly, Monthly)
    @param as_of_date
      - None: Only include complete periods (e.g., weeks ending Friday)
      - Some date: Include provisional value for incomplete period
        (e.g., Wednesday treated as week's close for intra-week computation)
    @return Price data at specified cadence

    Examples:
    {[
      (* Complete weeks only *)
      let weekly = convert_cadence daily_prices ~cadence:Weekly ~as_of_date:None

      (* Include provisional for Wednesday *)
      let provisional = convert_cadence daily_prices
        ~cadence:Weekly
        ~as_of_date:(Some wed_date)
    ]}
*)

val is_period_end : cadence:cadence -> Date.t -> bool
(** Check if date is a period boundary.

    - Daily: Always true
    - Weekly: True if Friday
    - Monthly: True if last day of month

    Used to determine when to finalize provisional indicator values.
*)
