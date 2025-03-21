open Core
open Types

val is_same_week : Date.t -> Date.t -> bool
(** Check if two dates are in the same week *)

val daily_to_weekly : Daily_price.t list -> Daily_price.t list
(** Convert daily data to weekly by taking the last entry of each week
    @param data List of data points with dates in chronological order *)
