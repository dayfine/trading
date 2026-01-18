(** Indicator computation from price data.

    This module computes technical indicators from historical price data. It is
    cadence-agnostic: the same code works for daily, weekly, or monthly data by
    converting prices to the desired cadence first. *)

open Core

type indicator_result = {
  symbol : string;
  indicator_values : Indicator_types.indicator_value list;
}
(** Result of indicator computation for a symbol *)

val compute_ema :
  symbol:string ->
  prices:Types.Daily_price.t list ->
  period:int ->
  cadence:Types.Cadence.t ->
  ?as_of_date:Date.t ->
  unit ->
  (indicator_result, Status.t) Result.t
(** Compute EMA (Exponential Moving Average) for a symbol.

    @param symbol The stock symbol
    @param prices Historical daily prices (chronological order)
    @param period EMA period (e.g., 10, 20, 50)
    @param cadence The cadence to compute on (Daily, Weekly, or Monthly)
    @param as_of_date Optional date for provisional values (Weekly only)
    @return Indicator result with EMA values, or error

    The computation: 1. Converts prices to the specified cadence 2. Extracts
    close prices as indicator values 3. Computes EMA using the specified period
    4. Returns results with dates aligned to cadence period-ends *)
