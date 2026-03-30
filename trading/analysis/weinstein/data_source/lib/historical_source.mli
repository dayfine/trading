(** Historical data source for backtesting — reads from local cache only.

    Represents the view of market data available at a single point in time
    during a simulation. The simulation engine advances time by creating a fresh
    instance with an updated [simulation_date] at each step; this module
    enforces that no data beyond that date is ever visible, regardless of what
    the strategy queries.

    Never makes API calls. All data must be pre-populated in the local cache.

    {1 No-lookahead guarantee}

    At step [t], the engine creates [make { data_dir; simulation_date = t }].
    Any query against that instance sees only bars with [date <= t]:
    - [get_bars ~end_date:None] returns bars up to [t] only
    - [get_bars ~end_date:(Some future)] is silently clamped to [t]
    - a bar dated [t + 1 day] is never returned *)

type config = {
  data_dir : string;
      (** Root directory for cached data files (default: ["./data"]) *)
  simulation_date : Core.Date.t;
      (** Date ceiling — no data after this date is visible *)
}
[@@deriving show, eq]
(** Configuration for the historical data source. *)

val make : config -> (module Data_source.DATA_SOURCE)
(** [make config] creates a historical data source with the given configuration.

    The returned module satisfies {!Data_source.DATA_SOURCE}. All queries are
    bounded by [config.simulation_date] to enforce no-lookahead.

    Note: [bar_query.period] is silently ignored — the cache stores bars at
    whatever cadence they were originally fetched, and no resampling is
    performed. Callers are responsible for querying at the correct cadence. *)
