(** Parse a single line of CSV data into a price_data record *)
val parse_line : string -> (Types.Daily_price.t, string) Result.t
