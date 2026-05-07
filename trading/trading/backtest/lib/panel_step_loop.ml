(** Step-loop helpers for [Panel_runner]: GC-tracing step iteration and progress
    accumulation. Extracted so [panel_runner.ml] stays under the normal-file
    line limit. *)

open Core
open Trading_simulation

(** Phase label for one step boundary. The date is the step-about-to-execute's
    date so a CSV consumer can pair [_before] and [_after] rows on it. *)
let step_phase ~date ~boundary =
  sprintf "step_%s_%s" (Date.to_string date) boundary

let step_failed e =
  failwith
    (sprintf "Backtest.Panel_runner: simulation failed: %s" (Status.show e))

(** One step iteration: snapshot [_before], call [Simulator.step], snapshot
    [_after], return either the final result or the next simulator state. *)
let step_with_gc_trace ?gc_trace ~date sim =
  Gc_trace.record ?trace:gc_trace
    ~phase:(step_phase ~date ~boundary:"before")
    ();
  let outcome = Simulator.step sim in
  Gc_trace.record ?trace:gc_trace ~phase:(step_phase ~date ~boundary:"after") ();
  outcome

(** One iteration of the step loop: snapshot before/after, dispatch on the
    outcome. Returns [`Done r] when the simulator completes, or
    [`Continue (sim', step_result)] with the next simulator state plus the
    per-step result (used to advance progress counters). *)
let step_loop_iter ?gc_trace ~date sim =
  match step_with_gc_trace ?gc_trace ~date sim with
  | Error e -> step_failed e
  | Ok (Simulator.Completed result) -> `Done result
  | Ok (Simulator.Stepped (sim', step_result)) -> `Continue (sim', step_result)

(** Build a progress accumulator from the optional emitter. Extracted so the
    [run] entry-point keeps low nesting. *)
let build_progress_acc ~progress_emitter ~warmup_start ~end_date =
  match progress_emitter with
  | None -> None
  | Some emitter ->
      let cycles_total =
        Backtest_progress.count_fridays_in_range ~start_date:warmup_start
          ~end_date
      in
      Some (Backtest_progress.create_accumulator ~cycles_total ~emitter ())

(** Forward a completed step into [progress_acc]. Pulled out of the step loop so
    the recursive [loop] body keeps low nesting. *)
let record_step_into_progress ~progress_acc ~date
    ~(step_result : Trading_simulation_types.Simulator_types.step_result) =
  match progress_acc with
  | None -> ()
  | Some acc ->
      Backtest_progress.record_step acc ~date
        ~trades_added:(List.length step_result.trades)
        ~portfolio_value:step_result.portfolio_value

(** Step-loop replacement for [Simulator.run] that snapshots [Gc.stat] before
    and after each [Simulator.step] call. [pending_date] is tracked locally in
    lockstep with the simulator's internal [current_date] so the [_before]
    snapshot is labeled with the step's date *before* [Simulator.step] is
    invoked. [progress_acc], when passed, has [Backtest_progress.record_step]
    invoked after every completed step; the caller is responsible for the final
    {!Backtest_progress.emit_final} call after the loop returns. *)
let run_simulator_with_gc_trace ?gc_trace ?progress_acc ~stop_log sim =
  let start_date = (Simulator.get_config sim).start_date in
  let rec loop sim ~pending_date =
    Stop_log.set_current_date stop_log pending_date;
    match step_loop_iter ?gc_trace ~date:pending_date sim with
    | `Done result -> result
    | `Continue (sim', step_result) ->
        record_step_into_progress ~progress_acc ~date:pending_date ~step_result;
        loop sim' ~pending_date:(Date.add_days pending_date 1)
  in
  loop sim ~pending_date:start_date
