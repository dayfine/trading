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
    current date and passes it to accessor functions.

    Two backends: {!create} (default, CSV-backed) and {!create_with_callbacks}
    (callback mode, used by the Phase D daily-snapshot path — see
    [dev/plans/daily-snapshot-streaming-2026-04-27.md]). Indicator +
    finalize_period are degenerate in callback mode (return [None] / no-op);
    the snapshot caller substitutes its own indicator backend at the strategy
    layer (Panel_strategy_wrapper). *)

open Core

type t
(** Market data adapter instance *)

val create : data_dir:Fpath.t -> t
(** Create market data adapter (CSV mode).

    @param data_dir Directory containing CSV price files *)

val create_with_callbacks :
  get_price:(symbol:string -> date:Date.t -> Types.Daily_price.t option) ->
  get_previous_bar:(symbol:string -> date:Date.t -> Types.Daily_price.t option) ->
  t
(** Create a market data adapter that delegates [get_price] /
    [get_previous_bar] to caller-supplied closures. {!get_indicator} returns
    [None] for every call and {!finalize_period} is a no-op (see top-of-module
    note). Phase D uses this with closures backed by [Daily_panels.t] —
    see [Backtest.Snapshot_bar_source]. *)

val get_price : t -> symbol:string -> date:Date.t -> Types.Daily_price.t option
(** Get price for symbol at specified date.

    Returns None if symbol not found or no price for that date. *)

val get_previous_bar :
  t -> symbol:string -> date:Date.t -> Types.Daily_price.t option
(** Get the most recent bar for [symbol] strictly before [date], or [None] if
    none exists. Used by split detection in the simulator step to compare
    today's bar against the prior trading day. *)

val get_indicator :
  t ->
  symbol:string ->
  indicator_name:string ->
  period:int ->
  cadence:Types.Cadence.t ->
  date:Date.t ->
  float option
(** Get indicator value for symbol at specified date.

    @param symbol Stock symbol
    @param indicator_name Indicator type ("EMA", etc.)
    @param period Indicator period (e.g., 20 for 20-period EMA)
    @param cadence Time cadence (Daily, Weekly, Monthly)
    @param date Date to compute indicator for
    @return
      Some value if computed, None if insufficient data. Always [None] in
      callback mode — see {!create_with_callbacks}. *)

val finalize_period : t -> cadence:Types.Cadence.t -> end_date:Date.t -> unit
(** Finalize a period, invalidating provisional indicator caches.

    Call at period boundaries (e.g., Friday for weekly) to ensure subsequent
    accesses recompute with finalized values. No-op in callback mode — see
    {!create_with_callbacks}. *)
