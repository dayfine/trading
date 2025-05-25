open Async
open Core

type fetch_fn = Uri.t -> (string, Status.t) Result.t Deferred.t
(** [fetch_fn uri] fetches the HTTP response body for the given [uri]. It
    returns either [Ok body] with the response body as a string, or
    [Error status] if the request fails. *)

val get_historical_price :
  token:string ->
  params:Http_params.historical_price_params ->
  ?fetch:fetch_fn ->
  unit ->
  (string, Status.t) Result.t Deferred.t

val get_symbols :
  token:string ->
  ?fetch:fetch_fn ->
  unit ->
  (string list, Status.t) result Deferred.t
(** Get a list of symbols for a given exchange *)
