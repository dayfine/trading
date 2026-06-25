(** Bar-panel world construction for the diagnostic runners (optimal-strategy,
    all-eligible).

    Both runners scan a universe over a window and need a
    {!Snapshot_runtime.Snapshot_callbacks.t} backed by a
    {!Snapshot_runtime.Daily_panels.t}. They can source the bars two ways:

    - from a {b pre-built snapshot warehouse} (its [manifest.sexp]) — used for
      broad universes (e.g. top-3000) the CSV [data/] store doesn't hold; or
    - by {b building an in-process snapshot from CSV} bars under a data dir (the
      same pipeline the CSV scenario-runner mode uses).

    This module unifies that construction so the two runners don't each carry a
    near-identical private helper. *)

open Core

val default_cache_mb : unit -> int
(** [default_cache_mb ()] is the LRU cache cap (MB) to pass as [max_cache_mb],
    read from the [SNAPSHOT_CACHE_MB] env var (the same knob [scenario_runner]'s
    snapshot mode reads), defaulting to 256 when unset/unparseable. Broad
    universes (top-3000 ≈ 420 MB working set) need a larger cap to avoid the LRU
    thrashing every symbol off disk each Friday. *)

val build_callbacks :
  warehouse_dir:string option ->
  data_dir:Fpath.t ->
  index_symbol:string ->
  universe:string list ->
  start:Date.t ->
  end_:Date.t ->
  max_cache_mb:int ->
  Snapshot_runtime.Snapshot_callbacks.t
(** [build_callbacks ~warehouse_dir ~data_dir ~index_symbol ~universe ~start
     ~end_ ~max_cache_mb] opens a [Snapshot_callbacks.t] over
    [universe ∪ {index_symbol}] for the [start..end_] window with an LRU cache
    capped at [max_cache_mb].

    When [warehouse_dir = Some dir] it reads [<dir>/manifest.sexp] and opens the
    pre-built warehouse directly (the [data_dir] / [start] / [end_] / [universe]
    args are unused for bar sourcing — the warehouse already holds them; the
    scan window still bounds which Fridays the caller walks). When [None] it
    materialises a tmp snapshot via [Csv_snapshot_builder.build] over [data_dir]
    (left on disk; the OS reaps it on reboot).

    Raises [Failure] if the warehouse manifest can't be read or
    [Daily_panels.create] fails. *)
