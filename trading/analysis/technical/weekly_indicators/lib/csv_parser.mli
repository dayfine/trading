open Types

(** Parse a single line of CSV data *)
val parse_line : string -> (price_data, string) result

(** Read and parse a CSV file.
    @param filename The path to the CSV file
    @return List of price data in chronological order (oldest first)
    @raise Failure if file cannot be read or has invalid format
*)
val read_file : string -> price_data list
