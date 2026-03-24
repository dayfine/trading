(** Historical data source for backtesting — reads from local cache only.

    Enforces no-lookahead: all date queries are clamped to [simulation_date].
    Any bar after [simulation_date] is invisible. This guarantees backtest
    integrity — the strategy cannot accidentally see future data.

    Never makes API calls. All data must be pre-populated in the local cache.

    {1 No-lookahead guarantee}

    With [simulation_date = 2023-06-30]:
    - [get_bars ~end_date:None] returns bars up to 2023-06-30 only
    - [get_bars ~end_date:(Some 2024-01-01)] is clamped to 2023-06-30
    - [get_daily_close ~date:2023-07-01] returns [None] *)

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
    bounded by [config.simulation_date] to enforce no-lookahead. *)
