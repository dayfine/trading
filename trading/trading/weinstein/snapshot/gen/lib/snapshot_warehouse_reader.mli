(** Build a snapshot-backed {!Weinstein_strategy.Bar_reader.t} from a pre-built
    snapshot warehouse directory.

    This is the fast bar-source path for {!Weekly_snapshot_generator.generate}:
    instead of loading every symbol's CSV bars into memory (the
    [Bar_reader.of_in_memory_bars] path, which materialises a fresh tmp snapshot
    on every run), it opens an already-built warehouse on disk and streams rows
    on demand via the LRU-bounded {!Snapshot_runtime.Daily_panels} cache — the
    same reader the backtest runners ([panel_runner], [optimal_strategy_runner],
    [decision_grading]) use.

    A warehouse is produced by the [build_snapshots] tool
    ([analysis/scripts/build_snapshots]); it is a directory of per-symbol
    [<SYMBOL>.snap] files plus a [manifest.sexp]. *)

open Core

val default_cache_mb : unit -> int
(** [default_cache_mb ()] is the LRU cache cap (MB) for the backing
    {!Snapshot_runtime.Daily_panels.t}, read from the [SNAPSHOT_CACHE_MB] env
    var (the same knob the backtest runners read), defaulting to 256 when
    unset/unparseable. *)

val build :
  warehouse_dir:string ->
  as_of:Date.t ->
  warmup_days:int ->
  ?max_cache_mb:int ->
  unit ->
  Weinstein_strategy.Bar_reader.t
(** [build ~warehouse_dir ~as_of ~warmup_days ?max_cache_mb ()] opens the
    snapshot warehouse at [warehouse_dir] (reading its [manifest.sexp]) and
    returns a {!Weinstein_strategy.Bar_reader.t} backed by it via
    {!Weinstein_strategy.Bar_reader.of_snapshot_views}.

    A real trading-day calendar (every weekday in
    [as_of - warmup_days .. as_of]) is passed to [of_snapshot_views] so the
    reader's daily/weekly windows are defined deterministically — the same
    calendar discipline [panel_runner] uses, and what the [of_snapshot_views]
    docstring requires for window determinism at history boundaries.
    [warmup_days] must cover the longest lookback the screener needs before
    [as_of] (the strategy's MA / base / breakout windows); too small a value
    truncates early history and changes which symbols screen.

    [max_cache_mb] defaults to {!default_cache_mb}.

    Raises [Failure] if the manifest can't be read or the panel store can't be
    opened (the "warehouse not built" failure mode surfaces immediately). *)
