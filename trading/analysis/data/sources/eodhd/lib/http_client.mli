open Async
open Core

type fetch_fn = Uri.t -> (string, Status.t) Result.t Deferred.t
(** [fetch_fn uri] fetches the HTTP response body for the given [uri]. It
    returns either [Ok body] with the response body as a string, or
    [Error status] if the request fails. *)

type historical_price_params = {
  symbol : string;
  (* If not specified, omitted from the API call *)
  start_date : Date.t option;
  (* If not specified, defaults to today *)
  end_date : Date.t option;
}

val get_historical_price :
  token:string ->
  params:historical_price_params ->
  ?fetch:fetch_fn ->
  unit ->
  (Types.Daily_price.t list, Status.t) Result.t Deferred.t

val get_symbols :
  token:string ->
  ?fetch:fetch_fn ->
  unit ->
  (string list, Status.t) Result.t Deferred.t
(** Get a list of symbols for a given exchange *)

val get_bulk_last_day :
  token:string ->
  exchange:string ->
  ?fetch:fetch_fn ->
  unit ->
  ((string * Types.Daily_price.t) list, Status.t) Result.t Deferred.t
(** Get the last day's prices for all symbols in a given exchange. Returns a
    list of tuples containing the symbol and its daily price data. *)
