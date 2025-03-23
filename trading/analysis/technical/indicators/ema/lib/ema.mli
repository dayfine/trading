open Indicator_types

val calculate_ema : indicator_value list -> int -> indicator_value list
(** Calculate exponential moving average from a series of indicator values
    @param data List of indicator values in chronological order
    @param period Number of periods to use for EMA calculation
    @return List of EMA results, starting from the nth period where n is the period *)
