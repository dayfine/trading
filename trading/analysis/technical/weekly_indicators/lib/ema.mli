open Core
open Types

val calculate_30_week_ema : Daily_price.t list -> (Date.t * float) list
(** Calculate the 30-week exponential moving average from price data
    @param data List of price data points in chronological order
    @return List of (date, ema_value) pairs, starting from the 30th week *)
