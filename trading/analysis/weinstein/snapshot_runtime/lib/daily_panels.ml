open Core
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

(* 1 MiB. Used to convert [max_cache_mb] to a byte budget. *)
let _bytes_per_mb = 1_048_576

(* Width of one Float64 cell on disk and on heap. *)
let _bytes_per_float = 8

(* Per-row byte estimate. The on-heap size of a [Snapshot.t] is dominated by
   the [values] float array ([n_fields * _bytes_per_float] bytes) plus
   per-record header / pointers; this constant captures the per-record
   overhead so the cache budget tracks GC-resident memory more honestly than
   counting only float bytes. Empirically the OCaml record header + symbol
   string dominate. *)
let _per_row_overhead_bytes = 64

(* One-time cost of holding a symbol's entry in the cache (linked-list node +
   hashtable bucket). Tiny next to the row payload but pinned out separately
   so the math stays explicit. *)
let _per_symbol_overhead_bytes = 128

(* Cached, decoded snapshot file for one symbol. [rows] is held by date order
   (the writer enumerates dates chronologically) as an array so [read_today] /
   [read_history] can binary-search by date in O(log N) instead of walking the
   list. [bytes] is the cache-budget contribution recomputed at insert time and
   never revised. *)
type cache_entry = { symbol : string; rows : Snapshot.t array; bytes : int }

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
}

(* --- Path resolution -------------------------------------------------- *)

let _resolve_path ~snapshot_dir (entry : Snapshot_manifest.file_metadata) =
  if Filename.is_absolute entry.path then entry.path
  else Filename.concat snapshot_dir entry.path

(* --- Byte estimation -------------------------------------------------- *)

let _estimate_bytes ~(schema : Snapshot_schema.t) (rows : Snapshot.t array) =
  let n_rows = Array.length rows in
  let row_value_bytes = Snapshot_schema.n_fields schema * _bytes_per_float in
  _per_symbol_overhead_bytes
  + (n_rows * (row_value_bytes + _per_row_overhead_bytes))

(* --- LRU helpers ------------------------------------------------------ *)

(* Promote an existing [elt] to MRU position. The elt remains valid, so the
   hashtable's stored elt pointer stays good. *)
let _promote_to_mru t (elt : cache_entry Doubly_linked.Elt.t) =
  Doubly_linked.move_to_front t.lru elt

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
      true

(* Drop entries until the budget is restored. Always leaves at least one
   entry resident if it was just inserted — i.e. the just-inserted entry is
   at the head and the loop walks from the tail. A single oversized entry
   (one symbol's bytes > budget) stays resident; the cap is best-effort, not
   a hard upper bound on a single symbol's memory. *)
let _enforce_budget t =
  let rec loop () =
    if t.bytes <= t.max_cache_bytes then ()
    else if Doubly_linked.length t.lru <= 1 then ()
    else if _evict_one t then loop ()
    else ()
  in
  loop ()

(* --- File loading ----------------------------------------------------- *)

let _load_symbol_file t (entry : Snapshot_manifest.file_metadata) =
  let path = _resolve_path ~snapshot_dir:t.snapshot_dir entry in
  Snapshot_format.read_with_expected_schema ~path ~expected:t.expected_schema

let _insert_into_cache t ~symbol ~rows =
  let bytes = _estimate_bytes ~schema:t.expected_schema rows in
  let entry = { symbol; rows; bytes } in
  let elt = Doubly_linked.insert_first t.lru entry in
  Hashtbl.set t.cache ~key:symbol ~data:elt;
  t.bytes <- t.bytes + bytes;
  _enforce_budget t;
  entry

(* Cache miss: look up the manifest entry, load + insert. The on-disk row
   list is converted to an array on insert (and sorted chronologically by
   date) so subsequent reads can binary-search by date. The writer is
   expected to emit rows in chronological order; the explicit sort is
   defensive. *)
let _sort_rows_by_date (rows : Snapshot.t array) =
  Array.sort rows ~compare:(fun a b -> Date.compare a.date b.date)

let _load_and_insert t ~symbol =
  match Snapshot_manifest.find t.manifest ~symbol with
  | None ->
      Status.error_not_found
        (Printf.sprintf "Daily_panels: symbol %s not in manifest" symbol)
  | Some metadata ->
      Result.map (_load_symbol_file t metadata) ~f:(fun rows_list ->
          let rows = Array.of_list rows_list in
          _sort_rows_by_date rows;
          _insert_into_cache t ~symbol ~rows)

(* Cache hit: promote to MRU and return the resident entry. *)
let _hit_path t (elt : cache_entry Doubly_linked.Elt.t) =
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

(* --- Binary search over chronologically-ordered rows ----------------- *)

(* Lowest index [i] in [rows[lo..hi)] such that [rows.(i).date >= target].
   Returns [hi] when every row in the half-open range is strictly before
   [target]. Pure: caller must ensure [rows] is sorted ascending by date. *)
let _lower_bound (rows : Snapshot.t array) ~lo ~hi ~target =
  let lo = ref lo and hi = ref hi in
  while !lo < !hi do
    let mid = (!lo + !hi) / 2 in
    if Date.( < ) rows.(mid).date target then lo := mid + 1 else hi := mid
  done;
  !lo

(* Lowest index [i] in [rows[lo..hi)] such that [rows.(i).date > target].
   Returns [hi] when every row in the half-open range is at or before
   [target]. Combined with {!_lower_bound} this gives an inclusive
   [from..until] slice in O(log N). *)
let _upper_bound (rows : Snapshot.t array) ~lo ~hi ~target =
  let lo = ref lo and hi = ref hi in
  while !lo < !hi do
    let mid = (!lo + !hi) / 2 in
    if Date.( <= ) rows.(mid).date target then lo := mid + 1 else hi := mid
  done;
  !lo

let read_today t ~symbol ~date =
  let open Result.Let_syntax in
  let%bind entry = _ensure_loaded t ~symbol in
  let n = Array.length entry.rows in
  let i = _lower_bound entry.rows ~lo:0 ~hi:n ~target:date in
  if i < n && Date.equal entry.rows.(i).date date then Ok entry.rows.(i)
  else
    Status.error_not_found
      (Printf.sprintf "Daily_panels.read_today: %s has no row for %s" symbol
         (Date.to_string date))

let read_history t ~symbol ~from ~until =
  let open Result.Let_syntax in
  let%bind entry = _ensure_loaded t ~symbol in
  let n = Array.length entry.rows in
  if Date.( > ) from until || n = 0 then Ok []
  else
    let lo = _lower_bound entry.rows ~lo:0 ~hi:n ~target:from in
    let hi = _upper_bound entry.rows ~lo ~hi:n ~target:until in
    if hi <= lo then Ok []
    else Ok (Array.to_list (Array.sub entry.rows ~pos:lo ~len:(hi - lo)))

let cache_bytes t = t.bytes

let close t =
  Doubly_linked.clear t.lru;
  Hashtbl.clear t.cache;
  t.bytes <- 0
