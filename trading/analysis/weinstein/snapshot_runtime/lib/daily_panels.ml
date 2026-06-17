open Core
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Backing = Daily_panels_backing

(* 1 MiB. Used to convert [max_cache_mb] to a byte budget. *)
let _bytes_per_mb = 1_048_576

(* Hard cap on resident [Mmap] backings, each of which holds an open fd. Sits
   comfortably under a typical 1024 fd ulimit so the cache never exhausts file
   descriptors even when the byte budget alone would admit far more mmap
   entries (their heap footprint is tiny). The eviction loop closes the LRU
   reader once this is exceeded. *)
let _max_open_mmap_handles = 256

(* Cached file for one symbol. [backing] is the format-detected store (mmap
   reader for v2, decoded rows for v1); [bytes] is the cache-budget
   contribution recomputed at insert time and never revised. *)
type cache_entry = { symbol : string; backing : Backing.t; bytes : int }

type stats = { hits : int; misses : int; evictions : int }
[@@deriving sexp, equal]

type t = {
  snapshot_dir : string;
  manifest : Snapshot_manifest.t;
  expected_schema : Snapshot_schema.t;
  max_cache_bytes : int;
  cache : (string, cache_entry Doubly_linked.Elt.t) Hashtbl.t;
  (* MRU-at-front linked list of cached symbols. Head = most recently used,
     tail = LRU. Eviction pops from tail. *)
  lru : cache_entry Doubly_linked.t;
  mutable bytes : int;
  (* Count of resident [Mmap] backings (= open fds). Capped at
     [_max_open_mmap_handles]; eviction closes readers to keep this bounded. *)
  mutable mmap_open : int;
  (* Cumulative cache-access counters since [create]. Surfaced via [cache_stats]
     for thrash diagnosis; never reset, not even by [close]. *)
  mutable hits : int;
  mutable misses : int;
  mutable evictions : int;
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
  t.bytes > t.max_cache_bytes || t.mmap_open > _max_open_mmap_handles

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

(* --- File loading ----------------------------------------------------- *)

let _insert_into_cache t ~symbol ~backing =
  let bytes = Backing.estimate_bytes ~schema:t.expected_schema backing in
  if Backing.is_mmap backing then t.mmap_open <- t.mmap_open + 1;
  let entry = { symbol; backing; bytes } in
  let elt = Doubly_linked.insert_first t.lru entry in
  Hashtbl.set t.cache ~key:symbol ~data:elt;
  t.bytes <- t.bytes + bytes;
  _enforce_limits t;
  entry

let _load_symbol_file t (entry : Snapshot_manifest.file_metadata) =
  let path = _resolve_path ~snapshot_dir:t.snapshot_dir entry in
  Backing.load ~path ~expected:t.expected_schema

let _load_and_insert t ~symbol =
  t.misses <- t.misses + 1;
  match Snapshot_manifest.find t.manifest ~symbol with
  | None ->
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

let _empty_cache ~snapshot_dir ~manifest ~max_cache_bytes =
  {
    snapshot_dir;
    manifest;
    expected_schema = manifest.Snapshot_manifest.schema;
    max_cache_bytes;
    cache = Hashtbl.create (module String);
    lru = Doubly_linked.create ();
    bytes = 0;
    mmap_open = 0;
    hits = 0;
    misses = 0;
    evictions = 0;
  }

let create ~snapshot_dir ~manifest ~max_cache_mb =
  if max_cache_mb <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf "Daily_panels.create: max_cache_mb must be positive: %d"
         max_cache_mb)
  else
    let max_cache_bytes = max_cache_mb * _bytes_per_mb in
    Ok (_empty_cache ~snapshot_dir ~manifest ~max_cache_bytes)

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

let cache_stats t =
  { hits = t.hits; misses = t.misses; evictions = t.evictions }

let close t =
  (* Release every resident entry first (closes [Mmap] fds), then clear the
     bookkeeping. Walking the list before clearing it ensures no fd leaks. *)
  Doubly_linked.iter t.lru ~f:(fun entry -> _release_entry t entry);
  Doubly_linked.clear t.lru;
  Hashtbl.clear t.cache;
  t.bytes <- 0;
  t.mmap_open <- 0
