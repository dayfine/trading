(** Snapshot LRU cache configuration + thrash diagnostics for the panel runner.

    The cache cap is an infra knob (memory budget for the decoded snapshot
    working set), not a strategy parameter, so it is resolved from an env var
    rather than threaded through [Weinstein_strategy.config]. *)

module Daily_panels = Snapshot_runtime.Daily_panels

val resolve_cache_mb : unit -> int
(** [resolve_cache_mb ()] returns the snapshot LRU cap (MB), read from the
    [SNAPSHOT_CACHE_MB] env var and falling back to the built-in default on an
    absent / unparseable / non-positive value. Logs the resolved value once to
    stderr. The default (4096 MB) holds an N~3000 PIT universe resident; the
    budget is best-effort (a single oversized symbol stays resident even when
    its bytes exceed the cap). *)

val log_cache_stats : daily_panels:Daily_panels.t -> n_symbols:int -> unit
(** [log_cache_stats ~daily_panels ~n_symbols] emits the cumulative cache
    hit/miss/eviction counters to stderr, plus [misses_per_symbol] — a thrash
    signal where ≈ 1 means the cache held the working set and a value
    approaching the cycle count means it thrashed (cap too small for the
    universe). Call before [Daily_panels.close] drops the cache. *)
