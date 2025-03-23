open Types

val daily_to_weekly :
  ?weekdays_only:bool -> Daily_price.t list -> Daily_price.t list
(** Convert daily data to weekly by taking the last entry of each week.
    @param weekdays_only If true, fails if weekend dates are present
    @param data List of data points with dates in chronological order
    @raise Invalid_argument if data is not sorted chronologically
    @raise Invalid_argument
      if weekdays_only is true and weekend dates are present *)
