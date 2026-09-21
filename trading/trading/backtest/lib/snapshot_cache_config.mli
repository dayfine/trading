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
    its bytes exceed the cap). The same line reports the resident-mmap handle
    cap ({!Daily_panels.default_max_mmap_handles}, env
    [SNAPSHOT_MAX_MMAP_HANDLES]) — on a v2 warehouse that cap, not the MB
    budget, is the effective cache size. *)

type process_high_water = { top_heap_bytes : int; maxrss_bytes : int }
(** Process-level memory high-water marks, both in bytes.

    - [top_heap_bytes] — OCaml major-heap peak ([Gc.quick_stat]'s
      [top_heap_words] scaled by the word size). Anonymous heap only.
    - [maxrss_bytes] — [getrusage(RUSAGE_SELF).ru_maxrss] (kB on Linux) scaled
      to bytes. {b Includes mapped file pages}, so on a v2 columnar warehouse it
      overstates the true footprint several-fold — the snapshot readers' pages
      count toward RSS but are evictable. Read it as a per-run trend number, not
      as headroom against the container limit; for headroom use
      [docker stats MemUsage] (see
      [.claude/rules/container-capacity-scheduling.md]). *)

val read_process_high_water : unit -> process_high_water
(** [read_process_high_water ()] samples the current process high-water marks.
    Cheap ([Gc.quick_stat] does not walk the heap); called once per run by
    {!log_cache_stats}. *)

val render_cache_stats_line :
  stats:Daily_panels.stats ->
  n_symbols:int ->
  cap_mb:int ->
  cap_mmap_handles:int ->
  high_water:process_high_water ->
  string

(** [render_cache_stats_line ~stats ~n_symbols ~cap_mb ~cap_mmap_handles
     ~high_water] renders the one-line run diagnostic {!log_cache_stats} emits.
    Pure, and separated from the emitter so the {b line format itself} — which
    chain scripts and post-mortems grep — is pinned by a test rather than by
    whatever a run happens to print.

    The line is a single space-separated [key=value] sequence prefixed
    ["Panel_runner: snapshot cache "], in this order:

    - [hits], [misses], [miss_absent], [evictions] — {!Daily_panels.stats}
      counters. [misses] retains its historical meaning (every non-hit read);
      [miss_absent] is the subset whose symbol is not in the manifest.
    - [n_symbols] — the caller's universe size, unchanged.
    - [misses_per_symbol] — [misses / n_symbols], unchanged and kept in the same
      position so existing greps still match.
    - [n_symbols_touched], [n_symbols_absent] — distinct symbols loaded, and
      distinct symbols looked up but missing from the manifest.
    - [loads_per_touched] — [(misses - miss_absent) / n_symbols_touched], the
      honest thrash ratio: ≈ 1 means each loaded symbol was decoded about once,
      a value near the cycle count means the cache thrashed. Unlike
      [misses_per_symbol] this is immune to both a universe larger than the
      touched set and to permanent negative lookups.
    - [max_entries], [max_bytes], [max_mmap_open], [avg_entries], [avg_bytes] —
      {!Daily_panels.occupancy}. [avg_bytes] is truncated to an integer;
      [avg_entries] keeps one decimal.
    - [cap_mb], [cap_mmap_handles] — the caps that were actually in force for
      this cache, so "did the cap bind?" is answerable by comparing them with
      [max_bytes] / [max_mmap_open] on the same line.
    - [top_heap_bytes], [maxrss_bytes] — see {!process_high_water}. *)

val log_cache_stats : daily_panels:Daily_panels.t -> n_symbols:int -> unit
(** [log_cache_stats ~daily_panels ~n_symbols] emits {!render_cache_stats_line}
    to stderr for [daily_panels], reading the caps off the cache itself (not off
    the environment, which can disagree when the cache was built via
    [Daily_panels.create_with_handle_cap]) and sampling the process high-water
    marks at call time. Call before [Daily_panels.close] drops the cache. *)
