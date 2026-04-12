(** Load stock-ticker → GICS-sector assignments from a CSV file.

    The canonical CSV lives at [data/sectors.csv] and is generated from SSGA
    SPDR ETF holdings data. Format: [symbol,sector] with a header line. *)

val load : data_dir:Fpath.t -> (string, string) Core.Hashtbl.t
(** [load ~data_dir] reads [data_dir/sectors.csv] and returns a hashtable
    mapping stock ticker (e.g. ["AAPL"]) to its GICS sector name (e.g.
    ["Information Technology"]).

    - If the file does not exist, returns an empty table.
    - Malformed rows (missing columns) are silently skipped.
    - The header line is skipped. *)
