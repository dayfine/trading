open Async
open Core

val historical_price_uri :
  ?testonly_today:Date.t option -> Http_params.t -> Uri.t
(** [historical_price_uri ?testonly_today params] Construct the URI for fetching
    historical price data for a given symbol and date range from the EODHD API.
    @param testonly_today
      Optional override for the 'today' date (used for testing)
    @param params The parameters specifying the symbol and date range
    @return The constructed [Uri.t] for the EODHD historical price API request
*)

val get_historical_price :
  token:string -> params:Http_params.t -> (string, Status.t) Result.t Deferred.t

val get_symbols : token:string -> (string list, Status.t) Result.t Deferred.t
(** Fetch list of US stock symbols from EODHD API *)
