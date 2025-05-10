(** CSV-based implementation of the HistoricalDailyPriceStorage interface *)

open Storage
include HistoricalDailyPriceStorage
open Core

type t

(** Create a new CSV storage with the given symbol and optional data directory.
    If no data directory is provided, a default value is used. *)
val create : ?data_dir:Fpath.t -> string -> (t, Status.t) Result.t

(** Save prices to CSV file *)
val save : t -> override:bool -> Types.Daily_price.t list -> (unit, Status.t) Result.t

(** Get prices from CSV file, optionally filtered by date range *)
val get : t -> ?start_date:Date.t -> ?end_date:Date.t -> unit -> (Types.Daily_price.t list, Status.t) Result.t
