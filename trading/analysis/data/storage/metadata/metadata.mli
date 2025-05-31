open Core

(** Status of metadata verification *)
type verification_status = Unverified | Verified | Failed | Pending
[@@deriving sexp, show]

type t = {
  symbol : string;
  last_verified : Date.t;
  verification_status : verification_status;
  data_start_date : Date.t;
  data_end_date : Date.t;
  has_volume : bool;
  last_n_prices_avg_below_10 : bool;
  last_n_prices_avg_above_500 : bool;
}
[@@deriving sexp, show]
(** Metadata for a stock's historical data *)

val generate_metadata : csv_path:string -> symbol:string -> n:int -> t
val validate_metadata : t -> csv_path:string -> bool

val save : t -> csv_path:string -> unit
(** Save metadata to a file next to the CSV
    @param t Metadata to save
    @param csv_path Path to the corresponding CSV file *)

val load : csv_path:string -> t option
(** Load metadata from file if it exists
    @param csv_path Path to the corresponding CSV file *)
