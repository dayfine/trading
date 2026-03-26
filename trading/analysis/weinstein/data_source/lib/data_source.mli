open Async
open Core

(** Uniform data access interface for the Weinstein analysis pipeline.

    Three implementations serve different use cases:
    - {b Live_source}: fetches from EODHD API, writes to local cache. Used for
      weekly live scans.
    - {b Historical_source}: reads from local cache with a date ceiling.
      Enforces no-lookahead for backtest integrity.
    - {b Synthetic_source}: generates price data programmatically. Used for
      stress testing and edge-case validation.

    All analysis and screening code is written against this interface. Swapping
    the implementation changes the data source without touching any analysis
    logic. *)

(** {1 Query parameters} *)

(** Parameters for a price bar query. *)
type bar_query = {
  symbol : string;
  period : Types.Cadence.t;
  start_date : Date.t option;
  end_date : Date.t option;
}
[@@deriving show, eq]
(** Bar query with optional date bounds. Use [None] for open-ended queries. *)

(** {1 Module type} *)

(** The common interface all data sources implement. *)
module type DATA_SOURCE = sig
  val get_bars :
    query:bar_query ->
    unit ->
    Types.Daily_price.t list Status.status_or Deferred.t
  (** [get_bars ~query ()] returns OHLCV bars for [query.symbol] at
      [query.period] cadence, optionally bounded by [query.start_date] and
      [query.end_date].

      For {!Historical_source}, [end_date] is clamped to the simulation date to
      prevent lookahead. The returned list is sorted ascending by date. *)

  val get_universe :
    unit -> Types.Instrument_info.t list Status.status_or Deferred.t
  (** [get_universe ()] returns the list of all tracked instruments with their
      fundamental metadata (sector, industry, market_cap, exchange).

      For {!Live_source}, this may trigger an API call if the cached universe
      file is stale. For {!Historical_source}, returns the cached snapshot. *)
end
