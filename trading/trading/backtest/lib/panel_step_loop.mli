(** Step-loop helpers for [Panel_runner]: GC-tracing step iteration and progress
    accumulation. *)

open Core
open Trading_simulation

val step_phase : date:Date.t -> boundary:string -> string
(** Phase label string for one step boundary: [step_<YYYY-MM-DD>_<boundary>]. *)

val step_failed : Status.t -> 'a
(** Raise a [Failure] describing a simulation step error. *)

val step_with_gc_trace :
  ?gc_trace:Gc_trace.t ->
  date:Date.t ->
  Simulator.t ->
  Simulator.step_outcome Status.status_or
(** Snapshot GC stats before and after one [Simulator.step] call. *)

val step_loop_iter :
  ?gc_trace:Gc_trace.t ->
  date:Date.t ->
  Simulator.t ->
  [ `Done of Trading_simulation_types.Simulator_types.run_result
  | `Continue of
    Simulator.t * Trading_simulation_types.Simulator_types.step_result ]
(** One full iteration of the step loop: GC-trace, then dispatch on outcome. *)

val build_progress_acc :
  progress_emitter:Backtest_progress.emitter option ->
  warmup_start:Date.t ->
  end_date:Date.t ->
  Backtest_progress.accumulator option
(** Build a progress accumulator from an optional emitter and date range. *)

val record_step_into_progress :
  progress_acc:Backtest_progress.accumulator option ->
  date:Date.t ->
  step_result:Trading_simulation_types.Simulator_types.step_result ->
  unit
(** Forward a completed step into [progress_acc] if present. *)

val run_simulator_with_gc_trace :
  ?gc_trace:Gc_trace.t ->
  ?progress_acc:Backtest_progress.accumulator ->
  stop_log:Stop_log.t ->
  Simulator.t ->
  Trading_simulation_types.Simulator_types.run_result
(** Drive the simulator to completion, GC-tracing each step. Calls
    [Backtest_progress.record_step] on every completed step when [progress_acc]
    is provided. *)
