val parse_line : string -> (Types.Daily_price.t, string) Result.t
(** Parse a single line of CSV data into a price_data record *)

val read_file : string -> (Types.Daily_price.t list, string) Result.t
(** Read a CSV file and parse all lines into a list of price_data records.
    Returns Ok with the list of records or Error with a message if something
    goes wrong. *)
