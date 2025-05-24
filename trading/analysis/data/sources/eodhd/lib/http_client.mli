open Async
open Core

type fetch_fn = Uri.t -> (string, Status.t) Result.t Deferred.t

val get_historical_price :
  token:string ->
  params:Http_params.historical_price_params ->
  ?fetch:fetch_fn ->
  unit ->
  (string, Status.t) Result.t Deferred.t

val get_symbols : token:string -> (string list, Status.t) Result.t Deferred.t
(** Fetch list of US stock symbols from EODHD API *)
