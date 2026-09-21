(** Occupancy accounting for {!Daily_panels}' LRU cache.

    Pure bookkeeping: peak + mean residency, and the distinct symbols the cache
    has ever seen. Nothing here is read by the load/evict path, so a run's
    cached data, eviction decisions and results are identical whether or not it
    is consulted — the module exists so the cap questions (#2839: "did the cap
    bind? what did the run actually peak at?") are answerable from a run log
    instead of from [/proc/<pid>] on a live worker.

    Split out of [daily_panels.ml] to keep that module under the file-length
    limit; {!Daily_panels} re-exports {!summary} as its [occupancy] type and
    owns the contract documentation (see [daily_panels.mli]). *)

type summary = {
  max_entries : int;
  max_bytes : int;
  max_mmap_open : int;
  avg_entries : float;
  avg_bytes : float;
}
[@@deriving sexp, equal]
(** High-water marks and running means over the samples fed to {!sample}. The
    means are [0.0] when no sample was ever taken. *)

type t
(** Mutable accumulator. One per cache, created empty and never reset — the
    figures are lifetime, so a caller can read them after a run. *)

val create : unit -> t
(** [create ()] is an accumulator with zeroed marks, zero samples, and empty
    distinct-symbol sets. *)

val sample : t -> entries:int -> bytes:int -> mmap_open:int -> unit
(** [sample t ~entries ~bytes ~mmap_open] folds one residency observation in:
    refreshes the three high-water marks and adds to the running means.

    The caller decides {i when} to sample; {!Daily_panels} does so once per
    insert, after cap enforcement, which is why the marks it reports are peak
    {b resident} occupancy rather than transient over-limit spikes. *)

val touch : t -> string -> unit
(** [touch t symbol] records [symbol] as having been loaded into the cache at
    least once. Idempotent. *)

val mark_absent : t -> string -> unit
(** [mark_absent t symbol] records [symbol] as having been looked up and found
    absent from the manifest. Idempotent; tracked separately from {!touch}
    because such a symbol is never loaded and never resident. *)

val n_touched : t -> int
(** [n_touched t] is the number of distinct symbols passed to {!touch}. *)

val n_absent : t -> int
(** [n_absent t] is the number of distinct symbols passed to {!mark_absent}. *)

val summary : t -> summary
(** [summary t] snapshots the accumulator. O(1); mutates nothing. *)
