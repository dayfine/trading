(** Periodic progress checkpoint written by the backtest runner during a long
    simulation.

    Mirrors the snapshot-build checkpointing pattern from PR 1 of the
    data-pipeline-automation track (see
    [dev/plans/data-pipeline-automation-2026-05-03.md] §"PR 2 — backtest
    checkpointing"). A 15y sp500 backtest emits no progress information today;
    after this PR a tail-able [progress.sexp] is rewritten under the run output
    directory every N Friday cycles (default 50) so the operator can gauge "10%
    complete vs. 90% complete" mid-run.

    The sexp shape is stable and pinned by the test suite. Atomic-write via
    tempfile + [Stdlib.Sys.rename] guarantees a tailing reader observes either
    the prior or the new value, never a torn write. *)

open Core

type t = {
  started_at : float;
      (** Unix seconds since epoch at the moment the run began. Stable across
          all checkpoints in a single run; useful for computing elapsed time
          [updated_at -. started_at] from any checkpoint. *)
  updated_at : float;
      (** Unix seconds since epoch at the moment this checkpoint was written.
          Advances on every checkpoint emission. *)
  cycles_done : int;
      (** Number of Friday cycles completed so far. Counts only Fridays
          encountered in the simulator's calendar walk; weekdays Mon–Thu and
          weekends do not increment this. *)
  cycles_total : int;
      (** Estimated total Friday cycles in the simulation window
          [warmup_start..end_date]. Computed once at simulation start as the
          number of Fridays in that calendar range. Stable across all
          checkpoints in a single run. *)
  last_completed_date : Date.t;
      (** The most recent simulator step's [pending_date] — i.e. the calendar
          day the last completed step ran on (typically a Friday at checkpoint
          emission, since checkpoints fire on Friday boundaries; on the final
          checkpoint it is whatever the simulator's last day was). *)
  trades_so_far : int;
      (** Cumulative count of trades observed across all simulator steps to
          date. Each [step_result.trades] list contributes its length. *)
  current_equity : float;
      (** Total portfolio value at the most recent step
          ([cash + market value of all positions]). Pulled from
          [step_result.portfolio_value]. *)
}
[@@deriving sexp]
(** On-disk progress checkpoint. *)

val write_atomic : path:string -> t -> unit
(** [write_atomic ~path progress] serializes [progress] to [path] using
    [Sexp.to_string_hum], via tempfile [path ^ ".tmp"] and atomic rename. On a
    filesystem error the tempfile is cleaned up best-effort and the error is
    logged to [stderr] but not raised — progress emission must never crash a
    long-running backtest. *)

val count_fridays_in_range : start_date:Date.t -> end_date:Date.t -> int
(** [count_fridays_in_range ~start_date ~end_date] returns the inclusive count
    of Fridays in [start_date..end_date]. Used by the runner to compute
    [cycles_total] once at simulation start. O(N) in days; cheap for any
    realistic backtest window. *)

type emitter = {
  every_n_fridays : int;
      (** Emit a checkpoint on every Nth Friday encountered. Must be [>= 1].
          Final-step emission is unconditional regardless of this setting, so
          the very last completed step always lands a [progress.sexp]. *)
  on_progress : t -> unit;
      (** Called by the runner with the current progress snapshot. The provided
          callback in the CLI is {!write_atomic}; tests can install a recording
          callback to pin emission cadence. *)
}
(** Bundle of emission cadence + sink callback, threaded through
    {!Backtest.Runner.run_backtest} as [?progress_emitter]. The runner owns the
    cycle-mod check; the emitter only specifies when and where. *)

type accumulator
(** Mutable accumulator threaded through the simulator step loop. Tracks
    [cycles_done] (Fridays completed), [trades_so_far] (cumulative trade count),
    and the most recent step's date + portfolio value. Encapsulates the
    per-Friday emission decision so the step-loop body keeps a low nesting
    profile. *)

val create_accumulator :
  cycles_total:int -> ?emitter:emitter -> unit -> accumulator
(** [create_accumulator ~cycles_total ?emitter ()] starts a fresh accumulator.
    [started_at] is captured here from [Core_unix.time ()]. When [emitter] is
    [None] every {!record_step} / {!emit_final} call becomes a cheap no-op. *)

val record_step :
  accumulator ->
  date:Date.t ->
  trades_added:int ->
  portfolio_value:float ->
  unit
(** [record_step acc ~date ~trades_added ~portfolio_value] is invoked from the
    step loop after every simulator step completes. It updates the running
    counters and, when [date] is a Friday whose cycle index is a multiple of the
    emitter's [every_n_fridays], invokes the emitter callback. *)

val emit_final : accumulator -> unit
(** [emit_final acc] writes one final [t] reflecting the most recently recorded
    step. No-op if no step was recorded or no emitter was attached. Called once
    after the simulator completes so [progress.sexp] always reflects the run's
    terminal state, regardless of cadence boundaries. *)
