open Indicator_types

val calculate_sma : indicator_value list -> int -> indicator_value list
(** Calculate simple moving average from a series of indicator values.

    @param data List of indicator values in chronological order
    @param period Number of periods to use for SMA calculation
    @return
      List of SMA results starting from the [period]-th element; earlier
      elements don't have enough history for a full window.

    Example: 5 values with period=3 produces 3 results (indices 2-4). *)

val calculate_weighted_ma : indicator_value list -> int -> indicator_value list
(** Calculate linearly weighted moving average (WMA) from a series of indicator
    values. The most recent observation receives the highest weight.

    Weight for observation [i] steps back from current = [period - i]. So for
    period=3: weights are [1, 2, 3] (oldest to newest), sum = 6.

    @param data List of indicator values in chronological order
    @param period Number of periods for WMA calculation
    @return List of WMA results starting from the [period]-th element. *)
