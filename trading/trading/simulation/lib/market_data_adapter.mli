(** Market data adapter for simulation.

    This module provides a unified interface for accessing market data during
    simulation, integrating price cache and indicator manager. It handles:
    - Lazy loading of prices via Price_cache
    - Indicator computation with caching via Indicator_manager

    {1 Design}

    The adapter sits between the strategy layer and backend services:
    {v
    Strategy Layer
        ↓
    Market Data Adapter (this module)
        ↓
    Indicator Manager ← → Price Cache
    v}

    Strategies call get_price and get_indicator without knowing about the
    underlying storage or caching mechanisms. The caller (simulator) manages the
    current date and passes it to accessor functions. *)

open Core

type t
(** Market data adapter instance *)

val create : data_dir:Fpath.t -> t
(** Create market data adapter.

    @param data_dir Directory containing CSV price files *)

val get_price : t -> symbol:string -> date:Date.t -> Types.Daily_price.t option
(** Get price for symbol at specified date.

    Returns None if symbol not found or no price for that date. *)

val get_indicator :
  t ->
  symbol:string ->
  indicator_name:string ->
  period:int ->
  cadence:Time_series.cadence ->
  date:Date.t ->
  float option
(** Get indicator value for symbol at specified date.

    @param symbol Stock symbol
    @param indicator_name Indicator type ("EMA", etc.)
    @param period Indicator period (e.g., 20 for 20-period EMA)
    @param cadence Time cadence (Daily, Weekly, Monthly)
    @param date Date to compute indicator for
    @return Some value if computed, None if insufficient data *)

val finalize_period :
  t -> cadence:Time_series.cadence -> end_date:Date.t -> unit
(** Finalize a period, invalidating provisional indicator caches.

    Call at period boundaries (e.g., Friday for weekly) to ensure subsequent
    accesses recompute with finalized values. *)
