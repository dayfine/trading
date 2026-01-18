(** Indicator management with caching and orchestration.

    This module orchestrates storage, time conversion, and indicator computation
    with intelligent caching. It handles:
    - Automatic lookback estimation based on indicator period and cadence
    - Provisional vs finalized value tracking for incomplete periods
    - Cache invalidation when periods complete

    {1 Overview}

    The indicator manager sits between the market data adapter and lower-level
    components (price_cache, time_series, indicator_computer), providing a
    unified interface for indicator access with caching.

    {1 Cache Behavior}

    - First access: Loads prices, converts cadence, computes indicator, caches
    - Subsequent access same date: Returns cached value (O(1))
    - Mid-period access (e.g., Wednesday for weekly): Cached as provisional
    - Period end (e.g., Friday for weekly): Cached as finalized
    - finalize_period: Invalidates provisional caches for completed period *)

open Core

type t
(** Indicator manager instance *)

type indicator_spec = {
  name : string;  (** Indicator name: "EMA", "RSI", etc. *)
  period : int;  (** Period: 10, 20, 50, etc. *)
  cadence : Types.Cadence.t;  (** Time cadence: Daily, Weekly, Monthly *)
}
[@@deriving show, eq]
(** Specification for an indicator computation *)

val create : price_cache:Price_cache.t -> t
(** Create indicator manager backed by a price cache.

    @param price_cache The price cache for loading historical data *)

val get_indicator :
  t ->
  symbol:string ->
  spec:indicator_spec ->
  date:Date.t ->
  (float option, Status.t) Result.t
(** Get indicator value for a symbol at a specific date.

    Automatically: 1. Checks cache for existing value 2. On cache miss: loads
    daily prices from price_cache 3. Converts to specified cadence (with
    provisional if mid-period) 4. Computes indicator value 5. Caches result with
    provisional/finalized flag

    @param symbol The stock symbol
    @param spec Indicator specification (name, period, cadence)
    @param date The date to get indicator for
    @return Some value if indicator can be computed, None if insufficient data
*)

val finalize_period : t -> cadence:Types.Cadence.t -> end_date:Date.t -> unit
(** Mark a period as finalized and invalidate provisional caches.

    Call this at period boundaries (e.g., Friday for weekly) to ensure
    subsequent accesses recompute with finalized values.

    @param cadence The cadence being finalized
    @param end_date The period end date (e.g., Friday's date for weekly) *)

val clear_cache : t -> unit
(** Clear all cached indicator values. *)

val cache_stats : t -> int * int
(** Get cache statistics: (total_entries, provisional_entries) *)
