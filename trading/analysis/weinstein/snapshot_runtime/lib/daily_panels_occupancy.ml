(** Occupancy accounting for {!Daily_panels}' LRU cache. See
    [daily_panels_occupancy.mli]. *)

open Core

type summary = {
  max_entries : int;
  max_bytes : int;
  max_mmap_open : int;
  avg_entries : float;
  avg_bytes : float;
}
[@@deriving sexp, equal]

(* [peak_*] are the high-water marks; [samples] + [sum_*] back the running
   means; [touched] / [absent] are the distinct-symbol sets. *)
type t = {
  mutable peak_entries : int;
  mutable peak_bytes : int;
  mutable peak_mmap_open : int;
  mutable samples : int;
  mutable sum_entries : int;
  mutable sum_bytes : int;
  touched : String.Hash_set.t;
  absent : String.Hash_set.t;
}

let create () =
  {
    peak_entries = 0;
    peak_bytes = 0;
    peak_mmap_open = 0;
    samples = 0;
    sum_entries = 0;
    sum_bytes = 0;
    touched = Hash_set.create (module String);
    absent = Hash_set.create (module String);
  }

let sample t ~entries ~bytes ~mmap_open =
  t.peak_entries <- Int.max t.peak_entries entries;
  t.peak_bytes <- Int.max t.peak_bytes bytes;
  t.peak_mmap_open <- Int.max t.peak_mmap_open mmap_open;
  t.samples <- t.samples + 1;
  t.sum_entries <- t.sum_entries + entries;
  t.sum_bytes <- t.sum_bytes + bytes

let touch t symbol = Hash_set.add t.touched symbol
let mark_absent t symbol = Hash_set.add t.absent symbol
let n_touched t = Hash_set.length t.touched
let n_absent t = Hash_set.length t.absent

(* Mean of [sum] over [samples]; 0.0 before the first sample — a cache that was
   never inserted into has no occupancy to average. *)
let _mean ~sum ~samples =
  if samples = 0 then 0.0 else Float.of_int sum /. Float.of_int samples

let summary t =
  {
    max_entries = t.peak_entries;
    max_bytes = t.peak_bytes;
    max_mmap_open = t.peak_mmap_open;
    avg_entries = _mean ~sum:t.sum_entries ~samples:t.samples;
    avg_bytes = _mean ~sum:t.sum_bytes ~samples:t.samples;
  }
