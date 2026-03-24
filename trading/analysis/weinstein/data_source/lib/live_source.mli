(** Live data source backed by EODHD API with local disk cache.

    Fetches data from the EODHD API and persists it to the local cache. On
    subsequent calls, returns cached data if current (last cached date >=
    yesterday), avoiding redundant API calls.

    Concurrent requests are throttled to [config.max_concurrent_requests] to
    respect EODHD rate limits (100K calls/day). *)

open Async

type config = {
  token : string;  (** EODHD API token *)
  data_dir : string;
      (** Root directory for cached data files (default: ["./data"]) *)
  max_concurrent_requests : int;
      (** Max concurrent EODHD API requests (default: [20]) *)
}
[@@deriving show, eq]
(** Configuration for the live data source. *)

val default_config : token:string -> config
(** [default_config ~token] creates a config with the given API token, using
    ["./data"] as the data directory and [20] concurrent requests. *)

val make :
  ?fetch:Eodhd.Http_client.fetch_fn ->
  config ->
  (module Data_source.DATA_SOURCE) Deferred.t
(** [make ?fetch config] creates a live data source.

    The optional [fetch] parameter overrides the HTTP fetch function, useful for
    testing without real network calls.

    The returned module satisfies {!Data_source.DATA_SOURCE}. Use
    {!Historical_source.make} for backtesting. *)
