open Types

(** Calculate the 30-week exponential moving average from price data
    @param data List of price data points in chronological order
    @return List of (date, ema_value) pairs, starting from the 30th week
*)
val calculate_30_week_ema : price_data list -> (date * float) list

(** Calculate the 30-week EMA directly from a CSV file
    @param filename Path to the CSV file containing price data
    @return List of (date, ema_value) pairs, starting from the 30th week
    @raise Failure if file cannot be read or has invalid format
*)
val calculate_from_file : string -> (date * float) list
