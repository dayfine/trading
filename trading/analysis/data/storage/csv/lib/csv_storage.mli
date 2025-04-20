(** CSV-based implementation of the HistoricalDailyPriceStorage interface *)

open Storage

include HistoricalDailyPriceStorage

val create_with_path : string -> (t, Status.t) result
(** [create_with_path path] creates a new storage instance for the given
    [symbol] at the specified [path]. This is useful for testing or when you
    need to specify a custom storage location. *)
