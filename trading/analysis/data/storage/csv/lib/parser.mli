val parse_lines : string list -> (Types.Daily_price.t list, Status.t) Result.t
(** Parse a list of lines of CSV data into a list of price_data records. Returns
    Ok with the list of records or Error with a message if something goes wrong.
*)
