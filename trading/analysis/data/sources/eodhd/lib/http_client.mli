open Async
open Core

type fetch_fn = Uri.t -> string Status.status_or Deferred.t
(** [fetch_fn uri] fetches the HTTP response body for the given [uri]. It
    returns either [Ok body] with the response body as a string, or
    [Error status] if the request fails. *)

type historical_price_params = {
  symbol : string;  (** If not specified, omitted from the API call *)
  start_date : Date.t option;  (** If not specified, defaults to today *)
  end_date : Date.t option;  (** If not specified, defaults to today *)
  period : Types.Cadence.t;
      (** Cadence of price bars. Defaults to [Daily] if not specified. *)
}

type fundamentals = {
  symbol : string;
  name : string;
  sector : string;
  industry : string;
  market_cap : float;
  exchange : string;
}
[@@deriving show, eq]
(** Fundamental data for a security, including sector and industry metadata. *)

val get_historical_price :
  token:string ->
  params:historical_price_params ->
  ?fetch:fetch_fn ->
  unit ->
  Types.Daily_price.t list Status.status_or Deferred.t
(** Fetch historical OHLCV price bars for a symbol.

    The [params.period] field controls whether daily, weekly, or monthly bars
    are returned. Use [Types.Cadence.Weekly] for Weinstein-style weekly
    analysis. *)

val get_fundamentals :
  token:string ->
  symbol:string ->
  ?fetch:fetch_fn ->
  unit ->
  fundamentals Status.status_or Deferred.t
(** Fetch fundamental data (sector, industry, market cap) for a symbol. *)

val get_index_symbols :
  token:string ->
  index:string ->
  ?fetch:fetch_fn ->
  unit ->
  string list Status.status_or Deferred.t
(** Fetch the constituent symbols of a market index (e.g. ["GSPC"] for S&P 500
    or ["DJI"] for Dow Jones Industrial Average). *)

val get_symbols :
  token:string ->
  ?fetch:fetch_fn ->
  unit ->
  string list Status.status_or Deferred.t
(** Get a list of symbols for a given exchange *)

val get_bulk_last_day :
  token:string ->
  exchange:string ->
  ?fetch:fetch_fn ->
  unit ->
  (string * Types.Daily_price.t) list Status.status_or Deferred.t
(** Get the last day's prices for all symbols in a given exchange. Returns a
    list of tuples containing the symbol and its daily price data. *)
