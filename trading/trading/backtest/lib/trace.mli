(** Per-phase tracing for backtest runs.

    Instruments the run loop with timing, symbol-count, and best-effort memory
    measurements for each logical phase, so a single sexp per run captures where
    time and memory are spent.

    Design notes:
    - A trace is a mutable collector. Passing [None] to the runner's [?trace]
      makes all recording a no-op.
    - Each call to [record] timestamps, runs the wrapped function, then appends
      one [phase_metrics] record. The original [('a -> 'b)] return value is
      passed through unchanged.
    - Output is one sexp per run at [dev/backtest/traces/<run-id>.sexp]. The
      caller (runner) picks the run id.

    Step 2 of the scale-optimization plan
    (dev/plans/backtest-scale-optimization-2026-04-17.md). *)

module Phase : sig
  (** Phases of a backtest run, in roughly the order they execute. Some are
      invoked once per run, others once per bar. The tracer records one
      [phase_metrics] per invocation of [record]; the runner picks granularity.
  *)
  type t =
    | Load_universe
    | Load_bars
    | Macro
    | Sector_rank
    | Rs_rank
    | Stage_classify
    | Screener
    | Stop_update
    | Order_gen
    | Fill
    | Teardown
  [@@deriving show, eq, sexp]
end

type phase_metrics = {
  phase : Phase.t;
  elapsed_ms : int;  (** Wall-clock elapsed, milliseconds. *)
  symbols_in : int option;
      (** Symbol count entering the phase (e.g. universe size). [None] means the
          caller did not measure this dimension for this phase — distinct from
          [Some 0] (measured zero). *)
  symbols_out : int option;
      (** Symbol count surviving the phase (e.g. screener hits). [None] vs
          [Some 0] semantics as for [symbols_in]. *)
  peak_rss_kb : int option;
      (** Best-effort peak resident set size in kB, read from
          [/proc/self/status] (VmHWM) after the phase. Kept in kB rather than MB
          so short-lived or small processes don't integer-truncate to 0 and hide
          real regressions. [None] on platforms that don't expose it or when
          reading fails. *)
  bar_loads : int option;
      (** Number of per-symbol bar loads attributed to this phase. [None] if the
          phase doesn't load bars. Exists primarily to distinguish cheap summary
          probes from full-history loads once step 3 (tier-aware loader) lands.
      *)
}
[@@deriving show, eq, sexp]
(** A single phase measurement. Emitted once per [record] call. *)

(** {1 Collector} *)

type t
(** Mutable collector of phase metrics. One per backtest run. Not safe to share
    across threads — the single-threaded backtest runner is the only expected
    caller. *)

val create : ?flush_path:string -> unit -> t
(** Create a fresh collector with no recorded phases.

    When [?flush_path] is [Some path], every subsequent {!record} call rewrites
    the file at [path] with the cumulative trace sexp (same format as {!write}).
    This ensures a partial trace survives a SIGKILL'd run (e.g. an OOM
    mid-backtest) — the smoking-gun phase is on disk by the time the process
    dies. The write is atomic via a [<path>.tmp] sibling + [Core_unix.rename],
    so a kill mid-flush leaves either the previous valid trace or the new one —
    never a truncated file. Parent directories are created on the first flush.

    Cost: one full sexp rewrite per [record] call. For a typical backtest (~5–20
    phases per call × ~1500 days = ~30K records, low single-digit MB final size)
    this is cheap relative to the work being measured. If profiling shows flush
    dominates wall-time the implementation can switch to append-only without an
    API change.

    Without [?flush_path], the collector is in-memory only and behaves
    identically to the pre-flush version — the caller is expected to call
    {!write} explicitly at end-of-run to persist. *)

val record :
  ?trace:t ->
  ?symbols_in:int ->
  ?symbols_out:int ->
  ?bar_loads:int ->
  Phase.t ->
  (unit -> 'a) ->
  'a
(** [record ?trace phase f] runs [f ()] and, if [trace] is [Some _], appends a
    [phase_metrics] row with measured [elapsed_ms] and [peak_rss_kb]. The
    optional [?symbols_in], [?symbols_out], [?bar_loads] are stored as [Some n]
    when passed and [None] when omitted.

    The [f ()] return value is always passed through, even when [trace] is
    [None] — so the caller can wrap any block unconditionally. *)

val snapshot : t -> phase_metrics list
(** Return the accumulated metrics in insertion order. Safe to call at any
    point; the collector is not consumed. *)

(** {1 Output} *)

val write : out_path:string -> phase_metrics list -> unit
(** Write [metrics] as a single sexp to [out_path], creating parent directories
    as needed. The sexp is a list of [phase_metrics] records, one per [record]
    call. Overwrites any existing file at [out_path].

    The sexp round-trips via the derived [sexp_of_phase_metrics] /
    [phase_metrics_of_sexp] — callers that want a parseable output should prefer
    [write] over ad-hoc printing. *)
