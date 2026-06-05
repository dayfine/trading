(** Inclusive date-windowing of a symbol's daily bars for the snapshot warehouse
    writer.

    [build_snapshots] loads each symbol's {e entire} CSV history and, when no
    window is requested, builds the snapshot off that full history. A
    full-history warehouse is pathologically slow to run: the snapshot runtime
    ({!Daily_panels}) decodes the whole per-symbol file on first access, and for
    a multi-hundred-symbol warehouse the decoded working set blows the 1 GB LRU
    cache → thrash → re-decode every symbol every cycle (~100x slower than CSV
    mode). {!Csv_snapshot_builder} avoids this by windowing each symbol's bars
    to the backtest range (incl. warmup) before building; this module gives the
    warehouse writer the same windowing as a pure, unit-testable helper.

    {b Warmup caveat.} Indicators (50-day SMA, 30-week MA, …) are computed by
    {!Snapshot_pipeline.Pipeline.build_for_symbol} walking {e only} the bars it
    is given. Bars before [start] are excluded here, so the windowed warehouse's
    earliest in-window dates carry NaN indicators until enough in-window samples
    accumulate — identical to the CSV path's contract. The {e caller} is
    therefore responsible for passing a [start] early enough to cover indicator
    warmup before the backtest's actual start — i.e. the backtest's
    {e warmup_start}, exactly as {!Csv_snapshot_builder.build} is invoked with
    [~warmup_start] from [panel_runner]. This helper does not auto-extend the
    lookback. *)

val filter :
  ?start:Core.Date.t ->
  ?end_:Core.Date.t ->
  Types.Daily_price.t list ->
  Types.Daily_price.t list
(** [filter ?start ?end_ bars] keeps only bars whose [date] falls in the
    inclusive window:

    - both [start] and [end_] given → [start <= date <= end_];
    - only [start] → [date >= start];
    - only [end_] → [date <= end_];
    - neither → [bars] unchanged (returned as-is).

    Relative bar order is preserved. The window is inclusive of both endpoints,
    matching {!Csv_storage.get}'s [~start_date]/[~end_date] semantics. *)
