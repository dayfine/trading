val parse_line : string -> (Types.Daily_price.t, string) Result.t
(** Parse a single (non-header) CSV line into a price record. Returns Ok with
    the record or Error with a message if the line is malformed. *)

val parse_lines : string list -> Types.Daily_price.t list Status.status_or
(** Parse a list of lines of CSV data into a list of price_data records. Returns
    Ok with the list of records or Error with a message if something goes wrong.
*)
