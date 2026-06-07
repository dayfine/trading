(** Snapshot LRU cache configuration + diagnostics — see
    [snapshot_cache_config.mli]. *)

open Core
module Daily_panels = Snapshot_runtime.Daily_panels

(* 4096 MB unblocks N=3000 (the decoded working set thrashed under the old 1 GB
   cap); env-overridable; an infra knob, not a strategy parameter (see
   dev/notes/macro-bearish-trim-grid-2026-06-07.md §7). *)
let _default_cache_mb = 4096
let _env_var = "SNAPSHOT_CACHE_MB"

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
  eprintf "Panel_runner: snapshot cache cap = %d MB (env %s)\n%!" resolved
    _env_var;
  resolved

let log_cache_stats ~daily_panels ~n_symbols =
  let stats = Daily_panels.cache_stats daily_panels in
  let misses_per_symbol =
    if n_symbols = 0 then 0.0
    else Float.of_int stats.misses /. Float.of_int n_symbols
  in
  eprintf
    "Panel_runner: snapshot cache hits=%d misses=%d evictions=%d n_symbols=%d \
     misses_per_symbol=%.2f\n\
     %!"
    stats.hits stats.misses stats.evictions n_symbols misses_per_symbol
