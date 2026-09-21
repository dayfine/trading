open Core
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Backing = Daily_panels_backing
module Occupancy = Daily_panels_occupancy

(* 1 MiB. Used to convert [max_cache_mb] to a byte budget. *)
let _bytes_per_mb = 1_048_576

(* Default cap on resident [Mmap] backings, each of which holds an open fd.
   Sits comfortably under a typical 1024 fd ulimit. Overridable per run via
   [SNAPSHOT_MAX_MMAP_HANDLES] (see [default_max_mmap_handles]) or per cache
   via [create_with_handle_cap ~max_mmap_handles]: a broad warehouse (~10k symbols) cycles a
   256-entry LRU on every weekly pass, so nearly every read reopens + remaps
   its file. Raising the cap to >= n_symbols is bit-identical by construction
   (a cache is a cache) and removes that churn (#2839). *)
let _default_max_mmap_handles = 256
let max_mmap_handles_env_var = "SNAPSHOT_MAX_MMAP_HANDLES"

let max_mmap_handles_of_env raw =
  match Option.bind raw ~f:(fun s -> Int.of_string_opt (String.strip s)) with
  | Some n when n > 0 -> n
  | _ -> _default_max_mmap_handles

let default_max_mmap_handles () =
  max_mmap_handles_of_env (Sys.getenv max_mmap_handles_env_var)

(* Cached file for one symbol. [backing] is the format-detected store (mmap
   reader for v2, decoded rows for v1); [bytes] is the cache-budget
   contribution recomputed at insert time and never revised. *)
type cache_entry = { symbol : string; backing : Backing.t; bytes : int }

type occupancy = Occupancy.summary = {
  max_entries : int;
  max_bytes : int;
  max_mmap_open : int;
  avg_entries : float;
  avg_bytes : float;
}
[@@deriving sexp, equal]

type stats = {
  hits : int;
  misses : int;
  miss_absent : int;
  evictions : int;
  n_symbols_touched : int;
  n_symbols_absent : int;
  occupancy : occupancy;
}
[@@deriving sexp, equal]

type resident = { entries : int; bytes : int; mmap_open : int }
[@@deriving sexp, equal]

type t = {
  snapshot_dir : string;
  manifest : Snapshot_manifest.t;
  expected_schema : Snapshot_schema.t;
  max_cache_bytes : int;
  (* Cap on resident [Mmap] backings (= open fds); see [create]. *)
  max_mmap_handles : int;
  cache : (string, cache_entry Doubly_linked.Elt.t) Hashtbl.t;
  (* MRU-at-front linked list of cached symbols. Head = most recently used,
     tail = LRU. Eviction pops from tail. *)
  lru : cache_entry Doubly_linked.t;
  mutable bytes : int;
  (* Count of resident [Mmap] backings (= open fds). Capped at
     [max_mmap_handles]; eviction closes readers to keep this bounded. *)
  mutable mmap_open : int;
  (* Cumulative cache-access counters since [create]. Surfaced via [cache_stats]
     for thrash diagnosis; never reset, not even by [close]. *)
  mutable hits : int;
  mutable misses : int;
  (* Subset of [misses] whose symbol is absent from the manifest. Such a read
     can never be served from cache, so it is charged on EVERY read of that
     symbol — a permanent negative lookup, not thrash. Split out so the
     thrash ratio can exclude it; [misses] keeps its original meaning. *)
  mutable miss_absent : int;
  mutable evictions : int;
  (* Occupancy telemetry. Observed only — never consulted by the eviction
     path, so residency decisions are bit-identical with or without it. *)
  occ : Occupancy.t;
}

(* --- Path resolution -------------------------------------------------- *)

let _resolve_path ~snapshot_dir (entry : Snapshot_manifest.file_metadata) =
  if Filename.is_absolute entry.path then entry.path
  else Filename.concat snapshot_dir entry.path

(* --- LRU helpers ------------------------------------------------------ *)

(* Promote an existing [elt] to MRU position. The elt remains valid, so the
   hashtable's stored elt pointer stays good. *)
let _promote_to_mru t (elt : cache_entry Doubly_linked.Elt.t) =
  Doubly_linked.move_to_front t.lru elt

(* Release the OS resources an entry holds. Only [Mmap] backings own an fd;
   closing one unmaps its columns and decrements the handle count. *)
let _release_entry t (entry : cache_entry) =
  if Backing.is_mmap entry.backing then t.mmap_open <- t.mmap_open - 1;
  Backing.close entry.backing

(* Evict the LRU symbol (linked-list tail). Returns [true] if anything was
   evicted; [false] when the cache is empty. *)
let _evict_one t =
  match Doubly_linked.last_elt t.lru with
  | None -> false
  | Some elt ->
      let entry = Doubly_linked.Elt.value elt in
      Doubly_linked.remove t.lru elt;
      Hashtbl.remove t.cache entry.symbol;
      t.bytes <- t.bytes - entry.bytes;
      _release_entry t entry;
      t.evictions <- t.evictions + 1;
      true

(* True while the cache is over either limit: the byte budget OR the open-fd
   handle cap. *)
let _over_limits t =
  t.bytes > t.max_cache_bytes || t.mmap_open > t.max_mmap_handles

(* Drop entries until both limits are satisfied. Always leaves at least one
   entry resident if it was just inserted — the just-inserted entry sits at the
   head and the loop walks from the tail. A single oversized entry stays
   resident; the byte cap is best-effort, not a hard upper bound on one
   symbol's memory. *)
let _enforce_limits t =
  let rec loop () =
    if not (_over_limits t) then ()
    else if Doubly_linked.length t.lru <= 1 then ()
    else if _evict_one t then loop ()
    else ()
  in
  loop ()

(* --- Occupancy telemetry ---------------------------------------------- *)

(* Feed the current residency to the occupancy accumulator. Called once per
   insert, AFTER [_enforce_limits] has restored both caps: inserts (and the
   evictions they trigger) are the only events that change residency, so one
   post-enforce sample per insert is a complete record of the distinct resident
   states the cache passed through — and the marks describe peak RESIDENT
   occupancy, never a transient over-limit spike. *)
let _sample_occupancy t =
  Occupancy.sample t.occ ~entries:(Hashtbl.length t.cache) ~bytes:t.bytes
    ~mmap_open:t.mmap_open

(* --- File loading ----------------------------------------------------- *)

let _insert_into_cache t ~symbol ~backing =
  let bytes = Backing.estimate_bytes ~schema:t.expected_schema backing in
  if Backing.is_mmap backing then t.mmap_open <- t.mmap_open + 1;
  let entry = { symbol; backing; bytes } in
  let elt = Doubly_linked.insert_first t.lru entry in
  Hashtbl.set t.cache ~key:symbol ~data:elt;
  t.bytes <- t.bytes + bytes;
  _enforce_limits t;
  Occupancy.touch t.occ symbol;
  _sample_occupancy t;
  entry

let _load_symbol_file t (entry : Snapshot_manifest.file_metadata) =
  let path = _resolve_path ~snapshot_dir:t.snapshot_dir entry in
  Backing.load ~path ~expected:t.expected_schema

let _load_and_insert t ~symbol =
  t.misses <- t.misses + 1;
  match Snapshot_manifest.find t.manifest ~symbol with
  | None ->
      t.miss_absent <- t.miss_absent + 1;
      Occupancy.mark_absent t.occ symbol;
      Status.error_not_found
        (Printf.sprintf "Daily_panels: symbol %s not in manifest" symbol)
  | Some metadata ->
      Result.map (_load_symbol_file t metadata) ~f:(fun backing ->
          _insert_into_cache t ~symbol ~backing)

(* Cache hit: promote to MRU and return the resident entry. *)
let _hit_path t (elt : cache_entry Doubly_linked.Elt.t) =
  t.hits <- t.hits + 1;
  _promote_to_mru t elt;
  Ok (Doubly_linked.Elt.value elt)

(* Returns the cache_entry, loading + inserting on miss. *)
let _ensure_loaded t ~symbol =
  match Hashtbl.find t.cache symbol with
  | Some elt -> _hit_path t elt
  | None -> _load_and_insert t ~symbol

(* --- Public API ------------------------------------------------------- *)

let _empty_cache ~snapshot_dir ~manifest ~max_cache_bytes ~max_mmap_handles =
  {
    snapshot_dir;
    manifest;
    expected_schema = manifest.Snapshot_manifest.schema;
    max_cache_bytes;
    max_mmap_handles;
    cache = Hashtbl.create (module String);
    lru = Doubly_linked.create ();
    bytes = 0;
    mmap_open = 0;
    hits = 0;
    misses = 0;
    miss_absent = 0;
    evictions = 0;
    occ = Occupancy.create ();
  }

let create_with_handle_cap ~max_mmap_handles ~snapshot_dir ~manifest
    ~max_cache_mb =
  if max_cache_mb <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf
         "Daily_panels.create_with_handle_cap: max_cache_mb must be positive: \
          %d"
         max_cache_mb)
  else if max_mmap_handles <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf
         "Daily_panels.create_with_handle_cap: max_mmap_handles must be \
          positive: %d"
         max_mmap_handles)
  else
    let max_cache_bytes = max_cache_mb * _bytes_per_mb in
    Ok (_empty_cache ~snapshot_dir ~manifest ~max_cache_bytes ~max_mmap_handles)

let create ~snapshot_dir ~manifest ~max_cache_mb =
  create_with_handle_cap
    ~max_mmap_handles:(default_max_mmap_handles ())
    ~snapshot_dir ~manifest ~max_cache_mb

let schema t = t.expected_schema

let read_today t ~symbol ~date =
  let open Result.Let_syntax in
  let%bind entry = _ensure_loaded t ~symbol in
  Backing.read_today entry.backing ~symbol ~date

let read_history t ~symbol ~from ~until =
  let open Result.Let_syntax in
  let%bind entry = _ensure_loaded t ~symbol in
  Backing.read_history entry.backing ~from ~until

let active_through_for t ~symbol =
  Option.bind (Snapshot_manifest.find t.manifest ~symbol)
    ~f:(fun (e : Snapshot_manifest.file_metadata) -> e.active_through)

let cache_bytes t = t.bytes
let max_cache_bytes t = t.max_cache_bytes
let max_mmap_handles t = t.max_mmap_handles

let resident t =
  ({
     entries = Hashtbl.length t.cache;
     bytes = t.bytes;
     mmap_open = t.mmap_open;
   }
    : resident)

let cache_stats t =
  {
    hits = t.hits;
    misses = t.misses;
    miss_absent = t.miss_absent;
    evictions = t.evictions;
    n_symbols_touched = Occupancy.n_touched t.occ;
    n_symbols_absent = Occupancy.n_absent t.occ;
    occupancy = Occupancy.summary t.occ;
  }

let close t =
  (* Release every resident entry first (closes [Mmap] fds), then clear the
     bookkeeping. Walking the list before clearing it ensures no fd leaks. *)
  Doubly_linked.iter t.lru ~f:(fun entry -> _release_entry t entry);
  Doubly_linked.clear t.lru;
  Hashtbl.clear t.cache;
  t.bytes <- 0;
  t.mmap_open <- 0
