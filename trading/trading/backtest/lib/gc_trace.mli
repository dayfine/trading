(** Phase-boundary [Gc.stat] snapshots for backtest runs.

    Companion to {!Trace} — where [Trace] captures per-phase wall-time + RSS,
    [Gc_trace] captures GC-internal counters ([major_words], [promoted_words],
    [minor_words], [heap_words], [top_heap_words]) at coarse lifecycle
    boundaries. Used by the hybrid-tier Phase 1 measurement infra to
    discriminate among load-time / per-tick / Friday-cycle residency hypotheses
    (see [dev/plans/hybrid-tier-phase1-2026-04-26.md]).

    Design notes:
    - Opt-in via [--gc-trace <path>] on [backtest_runner.exe]. Without the flag,
      no snapshots are taken and no file is written (zero overhead).
    - Output is one CSV per run with columns
      [phase,wall_ms,minor_words,promoted_words,major_words,heap_words,top_heap_words].
      CSV (not sexp) because the consumer is a human eyeballing the diff between
      phases and an OCaml port to Markdown is trivial.
    - [phase] is a free-form string label so the caller picks granularity (e.g.
      ["start"], ["load_universe_done"], ["fill_done"], ["end"]).
    - [Gc.stat] is called *without* a preceding [Gc.full_major] so the snapshot
      reflects the live state at the moment the call site is reached, not a
      forced-collected idealisation. Callers that want a compacted view can call
      [Gc.full_major] before [record]. *)

type snapshot = {
  phase : string;  (** Caller-chosen phase label. *)
  wall_ms : int;
      (** Wall-clock time elapsed since the {!t} was created, in milliseconds.
      *)
  minor_words : float;
      (** Bytes/8 allocated in the minor heap since program start. From
          [Gc.stat]. Cumulative — never decreases. *)
  promoted_words : float;
      (** Bytes/8 promoted from minor to major heap since program start. From
          [Gc.stat]. *)
  major_words : float;
      (** Bytes/8 allocated in the major heap (including promoted) since program
          start. From [Gc.stat]. *)
  heap_words : int;  (** Current size of the major heap, in words. *)
  top_heap_words : int;
      (** High-water mark of the major heap, in words.

          Multiply by [Sys.word_size / 8] to convert to bytes — on 64-bit OCaml
          that's 8 bytes per word, so [top_heap_words * 8] gives the peak heap
          byte count. *)
}
[@@deriving sexp]
(** A single GC measurement at a phase boundary. *)

(** {1 Collector} *)

type t
(** Mutable collector of GC snapshots. One per backtest run. Records the
    creation timestamp once on [create] so all subsequent [wall_ms] readings are
    relative to the same origin (giving meaningful cross-phase deltas). Not safe
    to share across threads. *)

val create : unit -> t
(** [create ()] returns a fresh collector with no recorded snapshots and the
    creation timestamp pinned to "now". *)

val record : ?trace:t -> phase:string -> unit -> unit
(** [record ?trace ~phase ()] reads the current [Gc.stat] and appends a
    {!snapshot} with label [phase] to [trace]. When [trace] is [None] this is a
    no-op (so call sites can wrap unconditionally; the runner only builds a [t]
    when [--gc-trace <path>] is passed). *)

val snapshot_list : t -> snapshot list
(** Return accumulated snapshots in insertion order. The collector is not
    consumed; safe to call at any point. *)

(** {1 Output} *)

val csv_header : string
(** [csv_header] is the CSV header line corresponding to {!snapshot}'s fields,
    in the same order [write] emits them. Useful for tests + consumers that want
    the schema declared in one place. *)

val write : out_path:string -> snapshot list -> unit
(** [write ~out_path snapshots] writes [snapshots] as CSV to [out_path],
    creating parent directories as needed. The first line is {!csv_header};
    subsequent lines are one row per snapshot in the same order.

    Float fields are emitted with [%.0f] — [Gc.stat] returns float-typed counts
    of words, but the values are integers in practice (the float type is a
    53-bit-mantissa workaround for OCaml's 63-bit int). The rounding matches
    what a human reads in the CSV. *)
