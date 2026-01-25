(** Multi-symbol price cache with lazy loading from CSV files.

    This module provides efficient access to historical price data for multiple
    symbols by:
    - Lazy loading: Only loads symbols when first accessed
    - Caching: Keeps loaded data in memory for subsequent queries
    - Date filtering: Returns only prices within requested date ranges

    Uses Csv.Csv_storage internally for actual file I/O. *)

open Core

type t
(** Price cache instance *)

val create : data_dir:Fpath.t -> t
(** Create a new price cache pointing to a data directory.

    The data directory should contain CSV files for historical prices. Symbols
    are loaded lazily on first access. *)

val get_prices :
  t ->
  symbol:string ->
  ?start_date:Date.t ->
  ?end_date:Date.t ->
  unit ->
  (Types.Daily_price.t list, Status.t) Result.t
(** Get historical prices for a symbol, optionally filtered by date range.

    On first access for a symbol, loads the CSV file and caches the data.
    Subsequent calls for the same symbol use the cached data.

    @param symbol The stock symbol (e.g., "AAPL")
    @param start_date Optional start date (inclusive)
    @param end_date Optional end date (inclusive)
    @return List of daily prices sorted by date (oldest first), or error *)

val preload_symbols : t -> string list -> (unit, Status.t) Result.t
(** Preload data for multiple symbols upfront.

    Useful for batch loading all symbols needed for a simulation. Returns Ok ()
    if all symbols loaded successfully, or Error with aggregated error message
    if any symbols failed to load. *)

val clear_cache : t -> unit
(** Clear all cached data. Useful for freeing memory or reloading data. *)

val get_cached_symbols : t -> string list
(** Get list of symbols currently cached in memory. *)
