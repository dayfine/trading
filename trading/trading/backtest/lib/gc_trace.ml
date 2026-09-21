(** Phase-boundary [Gc.stat] snapshots for backtest runs. See [gc_trace.mli]. *)

open Core

type cache_sample = { cache_entries : int; cache_bytes : int; mmap_open : int }
[@@deriving sexp]

type snapshot = {
  phase : string;
  wall_ms : int;
  minor_words : float;
  promoted_words : float;
  major_words : float;
  heap_words : int;
  top_heap_words : int;
  cache : cache_sample option;
}
[@@deriving sexp]

type t = {
  mutable entries : snapshot list;
  start_time : float;
      (** [Core_unix.gettimeofday ()] at [create] time. All subsequent [wall_ms]
          readings are relative to this origin. *)
}

let create () = { entries = []; start_time = Core_unix.gettimeofday () }

(** Read the current [Gc.stat] and shape it into a {!snapshot} for [phase].
    [Gc.stat] is called without a preceding [Gc.full_major] — the goal is to
    observe the live state at the call site, not a forced-collected
    idealisation. *)
let _read_snapshot ~phase ~wall_ms ~cache : snapshot =
  let s = Gc.stat () in
  {
    phase;
    wall_ms;
    minor_words = s.minor_words;
    promoted_words = s.promoted_words;
    major_words = s.major_words;
    heap_words = s.heap_words;
    top_heap_words = s.top_heap_words;
    cache;
  }

let record ?trace ?cache_sampler ~phase () =
  match trace with
  | None -> ()
  | Some t ->
      (* [cache_sampler] is only ever invoked inside this [Some] branch, so a
         run without [--gc-trace] pays nothing for it — same contract the rest
         of this module has always had. *)
      let cache = Option.map cache_sampler ~f:(fun f -> f ()) in
      let now = Core_unix.gettimeofday () in
      let wall_ms = Float.to_int ((now -. t.start_time) *. 1000.0) in
      let snap = _read_snapshot ~phase ~wall_ms ~cache in
      t.entries <- snap :: t.entries

let snapshot_list t = List.rev t.entries

let csv_header =
  "phase,wall_ms,minor_words,promoted_words,major_words,heap_words,top_heap_words,cache_entries,cache_bytes,mmap_open"

(* The three cache columns, or three empty fields when the snapshot carries no
   cache sample. Empty (rather than a sentinel like -1) so a consumer cannot
   mistake "not sampled" for a measured zero. *)
let _cache_columns = function
  | None -> ",,"
  | Some c -> sprintf "%d,%d,%d" c.cache_entries c.cache_bytes c.mmap_open

(** Format a single snapshot as one CSV row. Float fields use [%.0f] to match
    the integer semantics of [Gc.stat]'s word counts. *)
let _row_of_snapshot (s : snapshot) : string =
  sprintf "%s,%d,%.0f,%.0f,%.0f,%d,%d,%s" s.phase s.wall_ms s.minor_words
    s.promoted_words s.major_words s.heap_words s.top_heap_words
    (_cache_columns s.cache)

let write ~out_path snapshots =
  let parent = Filename.dirname out_path in
  Core_unix.mkdir_p parent;
  Out_channel.with_file out_path ~f:(fun oc ->
      Out_channel.output_string oc csv_header;
      Out_channel.newline oc;
      List.iter snapshots ~f:(fun s ->
          Out_channel.output_string oc (_row_of_snapshot s);
          Out_channel.newline oc))
