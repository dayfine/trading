(** Point-in-time index over the daily universe-breadth series.

    The daily breadth series is FIXED for a whole run (loaded once by
    {!Breadth_bars}), while the strategy queries it on every Friday tick. This
    module precomputes the two derived percentage arrays ONCE and answers each
    tick in O(log n): one binary search for the [as_of] cutoff plus O(1) array
    reads. It is the breadth twin of [Ad_series_cache], and it exists for the
    same reason — a per-tick rescan of the list would be O(n²) over a run.

    {1 Point-in-time contract}

    {!callbacks_at} never reads a row dated after [as_of]. This is the same
    lookahead guard [Macro_inputs]'s [*_at_or_before] helpers enforce for index
    and A-D inputs: a backtest that let a Friday's macro read Monday's breadth
    would not be measuring a tradeable rule.

    {1 Weekly offsets over a daily series}

    The callbacks are consumed at a {b weekly} cadence, but the underlying rows
    are {b daily}. The mapping is deliberately positional rather than
    calendar-based:

    - [week_offset:0] = the newest row at or before [as_of] (i.e. the Friday's
      own row, or the last session before it on a short week).
    - [week_offset:k] = the row {!trading_days_per_week} × k rows earlier in the
      series.

    Because {!Breadth_bars.load} has already dropped holiday rows, "5 rows back"
    is one trading week back, and [k = 4] is the ~20-trading-day lookback the
    27-year breadth study used. A calendar-date walk would have to invent a
    policy for market holidays and would drift against that study; counting rows
    cannot. Offsets that fall before the start of the series return [None]. *)

type t

val trading_days_per_week : int
(** Rows per [week_offset] step. 5 — the series carries one row per trading
    session with holidays already dropped. *)

val of_daily_bars : Macro_types.breadth_bar list -> t
(** [of_daily_bars bars] indexes [bars] (ascending by date, as
    {!Breadth_bars.load} returns). An empty list yields an empty cache whose
    {!callbacks_at} closures always return [None] — the breadth-inert mode. *)

val length : t -> int
(** Number of rows held. *)

val callbacks_at :
  t ->
  as_of:Core.Date.t ->
  (week_offset:int -> float option) * (week_offset:int -> float option)
(** [callbacks_at t ~as_of] returns the [(get_pct_above_ma, get_new_lows_pct)]
    pair {!Macro_types.callbacks} needs, computed over the prefix of rows with
    [date <= as_of].

    - [get_pct_above_ma ~week_offset]: percent of the universe above its 150-day
      MA, in [0, 100], at [week_offset] weeks back.
    - [get_new_lows_pct ~week_offset]: new 52-week lows as a percent of the
      universe, in [0, 100], at the same offset.

    Both return [None] when the offset falls outside the prefix (warmup, or an
    empty series). *)

module Internal_for_test : sig
  val count_at_or_before : t -> as_of:Core.Date.t -> int
  (** Prefix length: rows with [date <= as_of]. Exposed so the point-in-time
      guard can be pinned directly rather than inferred from callback output. *)
end
