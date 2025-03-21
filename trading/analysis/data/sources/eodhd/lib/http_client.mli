open Async
open Core

val to_uri : ?testonly_today:Date.t option -> Http_params.t -> Uri.t

val get_historical_price :
  token:string -> params:Http_params.t -> (string, string) Result.t Deferred.t
