open Core

(** Module type for storing and managing historical daily price data. This
    interface provides the core operations needed to manage historical price
    data with proper error handling and data integrity guarantees. *)
module type HistoricalDailyPriceStorage = sig
  type t
  (** The abstract type representing a storage instance for a specific symbol *)

  val create : string -> (t, Status.t) result
  (** [create symbol] creates a new storage instance for the given [symbol]. The
      storage will be initialized with default settings and empty data.

      Preconditions:
      - [symbol] must be a valid trading symbol

      Returns:
      - [Ok t] with a new storage instance
      - [Error status] if initialization fails, where status.code may be:
      - [Invalid_argument] if symbol is invalid
      - [Permission_denied] if storage location is not writable
      - [Resource_exhausted] if storage quota is exceeded
      - [Internal] for other initialization failures *)

  val save :
    t -> override:bool -> Types.Daily_price.t list -> (unit, Status.t) result
  (** [save t ~override prices] saves the set of [prices] to storage. If
      [override] is true, existing data will be overwritten.

      Preconditions:
      - [t] must be a valid storage instance
      - [prices] must be a non-empty set of valid price data
      - Storage location must be writable

      Returns:
      - [Ok ()] if save is successful
      - [Error status] if the save operation fails, where status.code may be:
      - [Invalid_argument] if prices are invalid (e.g., not sorted by date)
      - [Permission_denied] if storage location is not writable
      - [Resource_exhausted] if storage quota is exceeded
      - [Data_loss] if data corruption is detected
      - [Internal] for other save failures *)

  val get:
    t ->
    ?start_date:Date.t ->
    ?end_date:Date.t ->
    unit ->
    (Types.Daily_price.t list, Status.t) result
  (** [get t ?start_date ?end_date] returns prices from storage. If
      [start_date] is provided, only prices on or after that date are returned.
      If [end_date] is provided, only prices on or before that date are
      returned.

      Preconditions:
      - [t] must be a valid storage instance
      - Storage must exist and be accessible
      - If provided, [start_date] must be before or equal to [end_date]

      Returns:
      - [Ok prices] with the requested price data
      - [Error status] if the operation fails, where status.code may be:
      - [Invalid_argument] if date range is invalid
      - [NotFound] if storage does not exist
      - [Permission_denied] if storage is not readable
      - [Data_loss] if data corruption is detected
      - [Internal] for other retrieval failures *)
end
