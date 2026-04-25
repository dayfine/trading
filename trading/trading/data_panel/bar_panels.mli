(** Bar reader backed by [Ohlcv_panels] + a calendar.

    [Bar_panels.t] exposes the read API the Weinstein strategy needs over its
    OHLCV bar history — [daily_bars_for], [weekly_bars_for], [low_window] —
    backed entirely by an underlying [Ohlcv_panels.t] plus the universe trading
    calendar. Reads are zero-copy where possible (bar lists are reconstructed
    from panel cells on the fly; the support-floor low-window read returns a
    [Bigarray.Array2.sub_left] slice). No per-symbol cache, no parallel storage.

    This is the panel-backed replacement for {!Weinstein_strategy.Bar_history}.
    The two share the same shape ([Daily_price.t list] for the bar readers, an
    [as_of] parameter for time-bound reads) so call sites swap one for the other
    without touching downstream callees ([Stage.classify], [Sector.analyze],
    [Macro.analyze], [Stock_analysis.analyze],
    [Weinstein_stops.compute_initial_stop_with_floor]).

    Stage 2 invariant: there is no parallel cache. Bars on disk land in the
    OHLCV panels exactly once at backtest start (calendar-aware load); every
    strategy bar read derives from those panels.

    Bars are reconstructed only up to the [as_of] cursor, which the caller
    threads through (typically: today's column index, derived from the primary
    index's date in the simulator tick). Out-of-range or all-NaN cells produce
    the empty list — the same semantics [Bar_history] uses for unknown symbols
    or zero-bar histories. *)

type t

val create :
  ohlcv:Ohlcv_panels.t -> calendar:Core.Date.t array -> (t, Status.t) Result.t
(** [create ~ohlcv ~calendar] wraps an [Ohlcv_panels.t] in a bar reader.

    [calendar.(t)] must be the date written into column [t] of every panel — the
    same calendar that drove [Ohlcv_panels.load_from_csv_calendar]. The calendar
    length must equal [Ohlcv_panels.n_days ohlcv]; otherwise this returns
    [Error]. *)

val symbol_index : t -> Symbol_index.t
(** [symbol_index t] returns the universe bijection for [t]. *)

val n_days : t -> int
(** [n_days t] returns the calendar length. *)

val daily_bars_for :
  t -> symbol:string -> as_of_day:int -> Types.Daily_price.t list
(** [daily_bars_for t ~symbol ~as_of_day] returns the symbol's daily bars from
    panel column [0] up to and including column [as_of_day], in chronological
    order (oldest first). Cells where the close panel is NaN are skipped — the
    symbol either hadn't IPO'd, was suspended, or had a missing CSV row.

    Returns the empty list when [symbol] is not in the universe. Raises
    [Invalid_argument] if [as_of_day] is out of the half-open range
    [\[0, n_days t)]. *)

val weekly_bars_for :
  t -> symbol:string -> n:int -> as_of_day:int -> Types.Daily_price.t list
(** [weekly_bars_for t ~symbol ~n ~as_of_day] returns the most recent [n]
    weekly-aggregated bars for [symbol] as of column [as_of_day]. Daily bars are
    read from panels (via {!daily_bars_for}) and converted via
    {!Time_period.Conversion.daily_to_weekly} with [include_partial_week:true],
    matching {!Weinstein_strategy.Bar_history.weekly_bars_for}'s contract.

    Returns the empty list when the symbol is unknown or has no resident bars.
    Returns up to [n] weekly bars (fewer if [as_of_day] is early in the
    backtest). Raises [Invalid_argument] if [as_of_day] is out of range. *)

val low_window :
  t ->
  symbol:string ->
  as_of_day:int ->
  len:int ->
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array1.t option
(** [low_window t ~symbol ~as_of_day ~len] returns a zero-copy
    [Bigarray.Array2.sub_left]-equivalent view over the symbol's [Low] panel
    spanning columns [[as_of_day - len + 1, as_of_day]] inclusive — the
    support-floor 90-day window primitive.

    Returns [None] when [symbol] is unknown, when [as_of_day - len + 1 < 0], or
    when [len <= 0]. The returned [Bigarray.Array1.t] aliases the panel — no
    copy. Reads of the slice see live updates if the panel is mutated, but the
    strategy never writes to [Low]. *)
