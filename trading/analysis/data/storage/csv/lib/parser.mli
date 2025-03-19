open Types

val parse_line : string -> result
(** Parse a single line of CSV data into a price_data record *)

val to_string : price_data -> string
(** Convert a price_data record back to a CSV string *)
