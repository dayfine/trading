open Async
open Core

type fetch_fn = Uri.t -> string Status.status_or Deferred.t
(** [fetch_fn uri] fetches the HTTP response body for the given [uri]. It
    returns either [Ok body] with the response body as a string, or
    [Error status] if the request fails. *)

val default_fetch : fetch_fn
(** Default live HTTP fetcher, backed by [Cohttp_async.Client]. Sibling endpoint
    modules ({!Splits_endpoint}, {!Dividends_endpoint}) reuse this so all live
    HTTP traffic shares a single implementation. Tests inject a fixture-backed
    [fetch_fn] instead. *)

type historical_price_params = {
  symbol : string;  (** If not specified, omitted from the API call *)
  start_date : Date.t option;  (** If not specified, defaults to today *)
  end_date : Date.t option;  (** If not specified, defaults to today *)
  period : Types.Cadence.t;  (** Cadence of price bars. *)
}

type symbol_metadata = {
  code : string;  (** Ticker symbol, e.g. ["AAPL"]. *)
  name : string;
      (** Human-readable issuer / instrument name. Empty string if missing or
          null in the source. *)
  exchange : string;
      (** Listing exchange, e.g. ["NASDAQ"], ["NYSE ARCA"], ["PINK"]. Empty if
          missing or null. *)
  asset_type : Asset_type.t;
      (** Instrument classification used downstream by universe filters. *)
}
[@@deriving show, eq]
(** Per-symbol metadata returned by [/api/exchange-symbol-list/{ex}]. *)

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
  symbol_metadata list Status.status_or Deferred.t
(** Fetch the full US exchange symbol listing, including per-symbol [asset_type]
    / [name] / [exchange] metadata. Used downstream to drop mutual funds and
    other non-common-stock instruments from Weinstein-style universe-build (see
    [dev/plans/custom-universe-bidirectional-2026-05-17.md] §Q1). *)

val get_delisted_symbols :
  token:string ->
  ?fetch:fetch_fn ->
  unit ->
  symbol_metadata list Status.status_or Deferred.t
(** Fetch all DELISTED US-exchange symbols via the
    [/api/exchange-symbol-list/US?delisted=1] endpoint. Same schema as
    {!get_symbols} (Code / Name / Exchange / Type fields); the only difference
    is the [?delisted=1] query parameter, which flips the response from the ~14k
    currently-listed roster to the ~57k delisted roster (~31.7k Common Stock as
    of 2026-05-18).

    Used by the delisted-aware universe builder to recover symbols that delisted
    before the snapshot date and so are invisible to the live listings — fixes
    the construction-time survivor bias documented in PR #1180 +
    [dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md].

    The bars for each delisted symbol must still be fetched separately via
    {!get_historical_price}; EODHD retains bars for major delistings (TWTR, FIT)
    but not all small-cap delistings. *)

val get_bulk_last_day :
  token:string ->
  exchange:string ->
  ?fetch:fetch_fn ->
  unit ->
  (string * Types.Daily_price.t) list Status.status_or Deferred.t
(** Get the last day's prices for all symbols in a given exchange. Returns a
    list of tuples containing the symbol and its daily price data. *)
