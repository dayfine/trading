(** Phase B builder: per-symbol pipeline that turns daily CSV bars into a list
    of {!Snapshot.t} rows under a given {!Snapshot_schema.t}.

    Phase B of the daily-snapshot streaming pipeline (see
    [dev/plans/daily-snapshot-streaming-2026-04-27.md] §Phasing Phase B). The
    offline writer ([bin/build_snapshots.exe]) calls {!build_for_symbol} once
    per universe symbol and feeds the result list to {!Snapshot_format.write}.

    {2 Per-day rows from a per-symbol bar stream}

    The pipeline walks a symbol's daily bars in chronological order. For each
    day [d], it computes one {!Snapshot.t} row whose [values] array is
    column-aligned to [schema.fields] (per {!Snapshot.t}'s contract). The
    indicator value at column [i] is computed using only bars up to and
    including day [d] — the snapshot row at day [d] is causally consistent and
    leak-free.

    Indicator computations reuse the same analyser modules the runtime strategy
    consumes (parity guarantee per plan §R2):

    - {!EMA_50} / {!SMA_50}: rolling moving averages of [adjusted_close] over
      the previous 50 daily bars (NaN until 50 samples land).
    - {!ATR_14}: Wilder ATR over the previous 14 days (NaN at [d < 14]).
    - {!RSI_14}: Wilder RSI over the previous 14 days (NaN at [d < 14]).
    - {!Stage}: {!Weinstein.Stage.classify} run over the most recent 60 weekly
      bars aggregated from the symbol's daily history (encoded as
      [1.0 | 2.0 | 3.0 | 4.0]; [Float.nan] when fewer weekly bars than the
      classifier needs).
    - {!RS_line}: most-recent {!Rs.result.current_normalized} from
      {!Weinstein.Rs.analyze} run over weekly aggregates of the symbol vs the
      benchmark ([Float.nan] when no benchmark is supplied or RS is
      unavailable).
    - {!Macro_composite}: derived from the benchmark's own bars only —
      {!Weinstein.Macro.analyze} confidence (0.0–1.0). [Float.nan] when no
      benchmark is supplied.

    {2 Cross-symbol Macro_composite}

    Macro is **not** single-symbol-pure — it depends on a market index. Phase B
    handles this by accepting an optional [benchmark_bars] argument. The same
    Macro confidence scalar is written into every (symbol, day) row when the
    benchmark is supplied. [Macro_composite = Float.nan] when not. A-D and
    global-index data are not threaded in Phase B — Phase B uses the benchmark's
    stage-only signal as the macro proxy. (See plan §C1.)

    {2 Determinism}

    Pure function. Same [bars] + [schema] + [benchmark_bars] always produce the
    same row sequence. *)

val build_for_symbol :
  symbol:string ->
  bars:Types.Daily_price.t list ->
  schema:Data_panel_snapshot.Snapshot_schema.t ->
  ?benchmark_bars:Types.Daily_price.t list ->
  unit ->
  Data_panel_snapshot.Snapshot.t list Status.status_or
(** [build_for_symbol ~symbol ~bars ~schema ?benchmark_bars ()] returns one
    {!Snapshot.t} per bar in [bars] (chronological order, oldest first), with
    indicator values computed causally up to that bar's date.

    @param symbol Universe ticker stamped on every produced row.
    @param bars
      Daily bars for the symbol, sorted chronologically. Must be non-empty for a
      non-empty result; an empty input list returns [Ok []].
    @param schema
      Schema controlling field set + column layout. Every produced {!Snapshot.t}
      carries this schema.
    @param benchmark_bars
      Daily bars for the macro benchmark (e.g. ["SPY"]). When [None] (default),
      the {!RS_line} and {!Macro_composite} columns are filled with [Float.nan].
      When [Some], they are computed from the benchmark.

    Returns [Error Invalid_argument] when [symbol] is empty.

    Pure function. *)
