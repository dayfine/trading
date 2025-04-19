(** CSV-based implementation of the HistoricalDailyPriceStorage interface *)

include HistoricalDailyPriceStorage

(** [Storage_error] represents errors that can occur during storage operations
*)
type storage_error =
  | File_not_found of string
  | Invalid_file_format of string
  | IO_error of string
  | Data_integrity_error of string

exception Storage_error of storage_error

val create_with_path : string -> string -> t
(** [create_with_path symbol path] creates a new storage instance for the given
    [symbol] at the specified [path]. This is useful for testing or when you
    need to specify a custom storage location. *)
