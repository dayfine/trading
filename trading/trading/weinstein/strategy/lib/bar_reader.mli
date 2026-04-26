(** Bar source abstraction for the Weinstein strategy.

    Thin wrapper over {!Data_panel.Bar_panels} — the panel-backed reader that
    reconstructs OHLCV bars on the fly from the underlying [Ohlcv_panels]
    columns. The strategy reads daily / weekly bars through this interface,
    keyed on the strategy's notion of "current date" (the date of the primary
    index bar).

    Stage 3 PR 3.2 collapsed the dual-backend ([Bar_history] | [Bar_panels])
    abstraction into a single panel-backed reader. The [Bar_reader.t] type
    survives as a slim seam so callers and the strategy share one bar-reading
    API; future backend swaps (e.g. live-mode streaming reads) can be added by
    extending this module rather than every reader site. *)

open Core

type t
(** Opaque bar source. *)

val of_panels : Data_panel.Bar_panels.t -> t
(** [of_panels p] produces a reader backed by [Bar_panels]. The [as_of]
    parameter of the read functions is mapped to a panel column via
    {!Data_panel.Bar_panels.column_of_date}; when [as_of] is not in the
    underlying calendar (e.g., a date before the backtest start) the reader
    returns the empty list. *)

val empty : unit -> t
(** [empty ()] produces a reader with an empty universe / zero-day calendar. All
    reads return the empty list. Useful for tests that exercise control paths
    where the strategy never reaches a panel-backed read (e.g., empty universe,
    no held positions). *)

val daily_bars_for :
  t -> symbol:string -> as_of:Date.t -> Types.Daily_price.t list
(** [daily_bars_for t ~symbol ~as_of] returns daily bars for [symbol] up to and
    including [as_of], in chronological order (oldest first).

    Bars are reconstructed from the panel columns [0..as_of_day]. Returns the
    empty list when the symbol has no resident bars or [as_of] is out of the
    panel calendar. *)

val weekly_bars_for :
  t -> symbol:string -> n:int -> as_of:Date.t -> Types.Daily_price.t list
(** [weekly_bars_for t ~symbol ~n ~as_of] returns the most recent [n]
    weekly-aggregated bars for [symbol] as of [as_of]. Same semantics as
    {!Data_panel.Bar_panels.weekly_bars_for}.

    Returns the empty list when the symbol has no resident bars or [as_of] is
    out of the panel calendar. *)
