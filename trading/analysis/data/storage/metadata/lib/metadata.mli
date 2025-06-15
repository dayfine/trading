open Core

(** Status of metadata verification *)
type verification_status = Unverified | Verified | Failed | Pending
[@@deriving sexp, show, eq]

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
[@@deriving sexp, show, eq]
(** Metadata for a stock's historical data *)

(** Generate metadata for a symbol given its price data
    @param price_data List of daily price data
    @param symbol The trading symbol
    @param n Number of recent prices to consider for average calculations (default: 20)
*)
val generate_metadata : price_data:Types.Daily_price.t list -> symbol:string -> ?n:int -> unit -> t

val save : t -> csv_path:string -> unit
(** Save metadata to a file next to the CSV
    @param t Metadata to save
    @param csv_path Path to the corresponding CSV file *)

val load : csv_path:string -> t option
(** Load metadata from file if it exists
    @param csv_path Path to the corresponding CSV file *)
