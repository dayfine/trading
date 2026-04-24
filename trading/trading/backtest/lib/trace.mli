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
    | Promote_summary
        (** A batch of symbols promoted up to Summary tier by
            [Bar_loader.promote]. One record is emitted per [promote] call when
            a trace is attached to the loader. *)
    | Promote_full
        (** A batch of symbols promoted up to Full tier by [Bar_loader.promote].
            One record is emitted per [promote] call when a trace is attached to
            the loader. *)
    | Demote
        (** A batch of symbols demoted by [Bar_loader.demote]. One record is
            emitted per [demote] call regardless of the target tier — the
            target-tier dimension is carried in logs/scenario metadata, not in
            the phase tag. *)
    | Promote_metadata
        (** A bulk Metadata-tier promote of the universe at the start of a
            Tiered backtest. One record per
            [Tiered_runner.promote_universe_metadata] call (typically once per
            backtest). [symbols_in] is the universe size; per-symbol
            Metadata-promote calls fire {e inside} this wrap but do not
            themselves emit trace records — only this bulk wrap does. So this
            single record is the canonical observable for the Metadata-promote
            phase, not a per-symbol breakdown. *)
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

val create : unit -> t
(** Create a fresh collector with no recorded phases. *)

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
