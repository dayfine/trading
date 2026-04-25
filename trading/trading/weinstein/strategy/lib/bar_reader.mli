(** Bar source abstraction for the Weinstein strategy.

    The strategy reads OHLCV bars from one of two backends:

    - {!Bar_history} — the parallel per-symbol Hashtbl cache fed by
      [accumulate]/[seed]. Used by the Tiered backtest path during the data
      panels migration as long as panels are not yet wired into Tiered.
    - {!Data_panel.Bar_panels} — panel-backed reader that reconstructs bars on
      the fly from the underlying [Ohlcv_panels] columns. Used by the Panel
      backtest path. Eventually the only mode (Bar_history will be deleted in a
      follow-up).

    [Bar_reader.t] hides the choice behind three closures keyed on the
    strategy's notion of "current date" (the date of the primary index bar). The
    strategy never sees [Bar_history.t] or [Bar_panels.t] directly — it only
    constructs a [Bar_reader.t] at [make] time and consults it on every
    [on_market_close] call.

    {b Stage 2 invariant}: panels and history are mutually exclusive bar
    sources. A given [Bar_reader.t] is one or the other for the lifetime of the
    strategy instance — there is no fallback path between them at the reader
    level. *)

open Core

type t
(** Opaque bar source. *)

val of_history : Bar_history.t -> t
(** [of_history h] produces a reader backed by the bar-history cache. The
    [as_of] parameters of the read functions are ignored — [Bar_history] already
    filters bars at accumulate time, so the reader returns whatever bars are
    present in the cache at call time. *)

val of_panels : Data_panel.Bar_panels.t -> t
(** [of_panels p] produces a reader backed by [Bar_panels]. The [as_of]
    parameter is mapped to a panel column via
    {!Data_panel.Bar_panels.column_of_date}; when [as_of] is not in the
    underlying calendar (e.g., a date before the backtest start) the reader
    returns the empty list. *)

val daily_bars_for :
  t -> symbol:string -> as_of:Date.t -> Types.Daily_price.t list
(** [daily_bars_for t ~symbol ~as_of] returns daily bars for [symbol] up to and
    including [as_of], in chronological order (oldest first).

    For the panels backend, bars are reconstructed from the panel columns
    [0..as_of_day]. For the history backend, all bars in the cache are returned
    regardless of [as_of] (it's caller's responsibility to feed only
    on-or-before-today bars to [Bar_history.accumulate]).

    Returns the empty list when the symbol has no resident bars or [as_of] is
    out of the panel calendar. *)

val weekly_bars_for :
  t -> symbol:string -> n:int -> as_of:Date.t -> Types.Daily_price.t list
(** [weekly_bars_for t ~symbol ~n ~as_of] returns the most recent [n]
    weekly-aggregated bars for [symbol] as of [as_of]. Same semantics as
    {!Bar_history.weekly_bars_for} for the history backend (with [as_of]
    ignored) and as {!Data_panel.Bar_panels.weekly_bars_for} for the panels
    backend.

    Returns the empty list when the symbol has no resident bars or [as_of] is
    out of the panel calendar. *)

val accumulate :
  t ->
  get_price:Trading_strategy.Strategy_interface.get_price_fn ->
  symbols:string list ->
  unit
(** [accumulate t ~get_price ~symbols] is a no-op for the panels backend (the
    panels are populated by the runner before [on_market_close] is called) and
    delegates to {!Bar_history.accumulate} for the history backend.

    Threaded through the strategy's [on_market_close] so the existing
    Bar_history code path keeps working. Will become unnecessary once
    Bar_history is deleted. *)
