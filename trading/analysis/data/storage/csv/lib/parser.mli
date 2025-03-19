open Types

(** Parse a single line of CSV data into a price_data record *)
val parse_line : string -> result

(** Convert a price_data record back to a CSV string *)
val to_string : price_data -> string
