(** Fetch sector assignments from Finviz quote pages. *)

open Async

type manifest = {
  fetched_at : string;
  source : string;
  row_count : int;
  rate_limit_rps : float;
  errors : string list;
}
[@@deriving sexp]

type fetch_result = {
  symbol : string;
  sector : string option;
  error : string option;
}

type fetch_fn = Uri.t -> string Status.status_or Deferred.t

val parse_sector : string -> string option
val filter_common_stocks : Types.Instrument_info.t list -> string list
val load_existing_sectors : string -> (string, string) Core.Hashtbl.t

val write_sectors_csv :
  data_dir:string -> (string * string) list -> (unit, string) result

val load_manifest : string -> manifest option
val save_manifest : string -> manifest -> unit
val manifest_is_fresh : manifest -> max_age_days:int -> bool

val fetch_one :
  fetch:fetch_fn -> rate_limit_rps:float -> string -> fetch_result Deferred.t

val run :
  data_dir:string ->
  rate_limit_rps:float ->
  force:bool ->
  ?fetch:fetch_fn ->
  ?symbols:string list ->
  unit ->
  unit Deferred.t
