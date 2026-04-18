(** Per-phase tracing for backtest runs.

    Instruments the run loop with timing, symbol-count, and best-effort memory
    measurements for each logical phase, so a single sexp per run captures
    where time and memory are spent.

    Design notes:
    - A trace is a mutable collector. Passing [None] to the runner's [?trace]
      makes all recording a no-op.
    - Each call to [record] timestamps, runs the wrapped function, then appends
      one [phase_metrics] record. The original [('a -> 'b)] return value is
      passed through unchanged.
    - Output is one sexp per run at [dev/backtest/traces/<run-id>.sexp].
      The caller (runner) picks the run id.

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

  val to_string : t -> string
  (** Short lowercase_snake name, suitable for filenames or log prefixes. *)
end

(** A single phase measurement. Emitted once per [record] call. *)
type phase_metrics = {
  phase : Phase.t;
  elapsed_ms : int;  (** Wall-clock elapsed, milliseconds. *)
  symbols_in : int;
      (** Symbol count entering the phase (e.g. universe size). Use 0 if N/A. *)
  symbols_out : int;
      (** Symbol count surviving the phase (e.g. screener hits). Use 0 if N/A. *)
  peak_rss_mb : int option;
      (** Best-effort peak resident set size in MB, read from
          [/proc/self/status] after the phase. [None] on platforms that don't
          expose it or when reading fails. *)
  bar_loads : int;
      (** Number of per-symbol bar loads attributed to this phase. Use 0 if
          N/A. Exists primarily to distinguish cheap summary probes from
          full-history loads once step 3 (tier-aware loader) lands. *)
}
[@@deriving show, eq, sexp]

(** {1 Collector} *)

type t
(** Mutable collector of phase metrics. One per backtest run. *)

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
    [phase_metrics] row with measured [elapsed_ms] and [peak_rss_mb]. The
    optional [?symbols_in], [?symbols_out], [?bar_loads] are passed through
    verbatim (default 0).

    The [f ()] return value is always passed through, even when [trace] is
    [None] — so the caller can wrap any block unconditionally. *)

val snapshot : t -> phase_metrics list
(** Return the accumulated metrics in insertion order. Safe to call at any
    point; the collector is not consumed. *)

(** {1 Output} *)

val write : out_path:string -> phase_metrics list -> unit
(** Write [metrics] as a single sexp to [out_path], creating parent directories
    as needed. The sexp is a list of [phase_metrics] records, one per
    [record] call. Overwrites any existing file at [out_path].

    The sexp round-trips via the derived [sexp_of_phase_metrics] /
    [phase_metrics_of_sexp] — callers that want a parseable output should
    prefer [write] over ad-hoc printing. *)
