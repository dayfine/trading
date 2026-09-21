(** Snapshot LRU cache configuration + diagnostics — see
    [snapshot_cache_config.mli]. *)

open Core
module Daily_panels = Snapshot_runtime.Daily_panels

(* 4096 MB unblocks N=3000 (the decoded working set thrashed under the old 1 GB
   cap); env-overridable; an infra knob, not a strategy parameter (see
   dev/notes/macro-bearish-trim-grid-2026-06-07.md §7). *)
let _default_cache_mb = 4096
let _env_var = "SNAPSHOT_CACHE_MB"

(* Unit conversions. [_bytes_per_mb] mirrors [Daily_panels]' own MB -> byte
   factor (so the reported cap is the one actually in force, expressed in the
   unit the knob is set in); [_bytes_per_kb] converts getrusage's kB-valued
   [maxrss]. *)
let _bytes_per_mb = 1_048_576
let _bytes_per_kb = 1_024

(* Bits per byte — the divisor that turns [Sys.word_size_in_bits] into the
   byte-per-word factor [Gc]'s word counts are scaled by. *)
let _bits_per_byte = 8
let _bytes_per_word = Sys.word_size_in_bits / _bits_per_byte

(* Parse a strictly-positive int from [raw], tolerating surrounding whitespace.
   Returns [None] on an unparseable or non-positive value. *)
let _parse_positive_int raw =
  match Int.of_string_opt (String.strip raw) with
  | Some n when n > 0 -> Some n
  | _ -> None

let resolve_cache_mb () =
  let resolved =
    match Option.bind (Sys.getenv _env_var) ~f:_parse_positive_int with
    | Some n -> n
    | None -> _default_cache_mb
  in
  eprintf
    "Panel_runner: snapshot cache cap = %d MB (env %s), max mmap handles = %d \
     (env %s)\n\
     %!"
    resolved _env_var
    (Daily_panels.default_max_mmap_handles ())
    Daily_panels.max_mmap_handles_env_var;
  resolved

type process_high_water = { top_heap_bytes : int; maxrss_bytes : int }

let read_process_high_water () =
  let gc = Gc.quick_stat () in
  let ru = Core_unix.Resource_usage.get `Self in
  {
    top_heap_bytes = gc.top_heap_words * _bytes_per_word;
    maxrss_bytes = Int64.to_int_exn ru.maxrss * _bytes_per_kb;
  }

(* [num / den] as a float, 0 for an empty denominator — a run that touched no
   symbols has no ratio to report. *)
let _ratio ~num ~den =
  if den = 0 then 0.0 else Float.of_int num /. Float.of_int den

let render_cache_stats_line ~(stats : Daily_panels.stats) ~n_symbols ~cap_mb
    ~cap_mmap_handles ~high_water =
  sprintf
    "Panel_runner: snapshot cache hits=%d misses=%d miss_absent=%d \
     evictions=%d n_symbols=%d misses_per_symbol=%.2f n_symbols_touched=%d \
     n_symbols_absent=%d loads_per_touched=%.2f max_entries=%d max_bytes=%d \
     max_mmap_open=%d avg_entries=%.1f avg_bytes=%d cap_mb=%d \
     cap_mmap_handles=%d top_heap_bytes=%d maxrss_bytes=%d"
    stats.hits stats.misses stats.miss_absent stats.evictions n_symbols
    (_ratio ~num:stats.misses ~den:n_symbols)
    stats.n_symbols_touched stats.n_symbols_absent
    (_ratio
       ~num:(stats.misses - stats.miss_absent)
       ~den:stats.n_symbols_touched)
    stats.occupancy.max_entries stats.occupancy.max_bytes
    stats.occupancy.max_mmap_open stats.occupancy.avg_entries
    (Float.to_int stats.occupancy.avg_bytes)
    cap_mb cap_mmap_handles high_water.top_heap_bytes high_water.maxrss_bytes

let log_cache_stats ~daily_panels ~n_symbols =
  let line =
    render_cache_stats_line
      ~stats:(Daily_panels.cache_stats daily_panels)
      ~n_symbols
      ~cap_mb:(Daily_panels.max_cache_bytes daily_panels / _bytes_per_mb)
      ~cap_mmap_handles:(Daily_panels.max_mmap_handles daily_panels)
      ~high_water:(read_process_high_water ())
  in
  eprintf "%s\n%!" line
