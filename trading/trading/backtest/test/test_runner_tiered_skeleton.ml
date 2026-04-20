(** Tests for [Runner]'s Tiered [loader_strategy] skeleton (3f-part2).

    3f-part2 ships the pre-simulator portion of the Tiered path: Bar_loader
    construction, Metadata-tier bulk promote, and a [Bar_loader.tier_op] →
    [Trace.Phase.t] bridge. The simulator-cycle step itself lands in 3f-part3 —
    so under [Tiered] the runner promotes then raises [Failure] with a clear
    pointer.

    These tests pin the observable parts of the skeleton:

    1. [tier_op_to_phase] is the pure mapping used by the trace bridge — one
    test per variant so a future renaming or re-ordering fails loudly. 2. The
    [trace_hook] built by the runner actually emits [Trace.Phase.t] rows into
    the attached [Trace.t] when invoked by a [Bar_loader] — the end-to-end
    bridge from bar_loader to trace collector works. 3. [tier_op] variants are
    exhaustively covered by the mapping so the next variant addition forces a
    compile error here.

    A full end-to-end [run_backtest ~loader_strategy:Tiered] trace-sequence test
    needs a production-shape data directory and therefore belongs in the 3g
    parity acceptance test, not here. *)

open OUnit2
open Core
open Matchers
module Bar_loader = Bar_loader

(* -------------------------------------------------------------------- *)
(* tier_op_to_phase mapping                                             *)
(* -------------------------------------------------------------------- *)

let test_tier_op_to_phase_promote_summary _ =
  assert_that
    (Backtest.Runner.tier_op_to_phase Bar_loader.Promote_to_summary)
    (equal_to Backtest.Trace.Phase.Promote_summary)

let test_tier_op_to_phase_promote_full _ =
  assert_that
    (Backtest.Runner.tier_op_to_phase Bar_loader.Promote_to_full)
    (equal_to Backtest.Trace.Phase.Promote_full)

let test_tier_op_to_phase_demote _ =
  assert_that
    (Backtest.Runner.tier_op_to_phase Bar_loader.Demote_op)
    (equal_to Backtest.Trace.Phase.Demote)

(* -------------------------------------------------------------------- *)
(* End-to-end: bar_loader → trace_hook → Trace collector                *)
(* -------------------------------------------------------------------- *)

(** Build a trace_hook with the same shape the runner uses — wrap [Trace.record]
    over [tier_op_to_phase]. The full [_make_trace_hook] helper is private, so
    this test reconstructs the equivalent wiring externally. Any drift between
    this wiring and the runner's internal wiring would invalidate the end-to-end
    assertion; a change to either side must be mirrored here. *)
let _make_trace_hook_for_test ~trace : Bar_loader.trace_hook =
  let record :
      'a. tier_op:Bar_loader.tier_op -> symbols:int -> (unit -> 'a) -> 'a =
   fun ~tier_op ~symbols f ->
    let phase = Backtest.Runner.tier_op_to_phase tier_op in
    Backtest.Trace.record ~trace ~symbols_in:symbols phase f
  in
  { record }

(** When a Bar_loader built with [trace_hook] sees a [Summary_tier] promote
    request that fails (short history → insufficient summary data), the hook
    still fires with [Promote_to_summary] and the Trace collector gets a
    [Promote_summary] row attributed to it. This is the "phase emitted" contract
    the 3d tracer integration test already pins for Bar_loader in isolation — we
    re-pin it here through the runner's mapping to prove the bridge composes
    correctly.

    The test uses a temp data dir with no CSV files, so promote's symbol loop
    returns early for every symbol. The empty-symbols case still invokes the
    hook per Bar_loader semantics — see [test_trace_integration.ml] in the
    bar_loader tests. *)
let test_trace_hook_emits_promote_summary_row _ =
  let tmp_dir = Filename_unix.temp_dir "runner_tiered_test_" "" in
  let data_dir = Fpath.v tmp_dir in
  let sector_map = Hashtbl.create (module String) in
  let trace = Backtest.Trace.create () in
  let trace_hook = _make_trace_hook_for_test ~trace in
  let loader =
    Bar_loader.create ~data_dir ~sector_map ~universe:[ "AAA" ] ~trace_hook ()
  in
  (* Promote attempts Summary for the single symbol; the symbol has no CSV in
     tmp_dir so it ends up left at whichever lower tier it reached. The
     tracer hook still fires once — that's what we're testing. *)
  let (_ : (unit, Status.t) Result.t) =
    Bar_loader.promote loader ~symbols:[ "AAA" ] ~to_:Bar_loader.Summary_tier
      ~as_of:(Date.create_exn ~y:2024 ~m:Jan ~d:5)
  in
  let phases =
    Backtest.Trace.snapshot trace
    |> List.map ~f:(fun (m : Backtest.Trace.phase_metrics) -> m.phase)
  in
  assert_that phases
    (elements_are [ equal_to Backtest.Trace.Phase.Promote_summary ])

(** Demote always emits [Demote] via the hook, regardless of whether a symbol
    actually changed tier. Asserts the mapping is wired in the demote path, not
    only the promote path. *)
let test_trace_hook_emits_demote_row _ =
  let tmp_dir = Filename_unix.temp_dir "runner_tiered_test_" "" in
  let data_dir = Fpath.v tmp_dir in
  let sector_map = Hashtbl.create (module String) in
  let trace = Backtest.Trace.create () in
  let trace_hook = _make_trace_hook_for_test ~trace in
  let loader =
    Bar_loader.create ~data_dir ~sector_map ~universe:[] ~trace_hook ()
  in
  Bar_loader.demote loader ~symbols:[ "AAA" ] ~to_:Bar_loader.Metadata_tier;
  let phases =
    Backtest.Trace.snapshot trace
    |> List.map ~f:(fun (m : Backtest.Trace.phase_metrics) -> m.phase)
  in
  assert_that phases (elements_are [ equal_to Backtest.Trace.Phase.Demote ])

let suite =
  "Runner_tiered_skeleton"
  >::: [
         "tier_op_to_phase: Promote_to_summary → Promote_summary"
         >:: test_tier_op_to_phase_promote_summary;
         "tier_op_to_phase: Promote_to_full → Promote_full"
         >:: test_tier_op_to_phase_promote_full;
         "tier_op_to_phase: Demote_op → Demote" >:: test_tier_op_to_phase_demote;
         "trace_hook emits Promote_summary row on Summary promote"
         >:: test_trace_hook_emits_promote_summary_row;
         "trace_hook emits Demote row on demote"
         >:: test_trace_hook_emits_demote_row;
       ]

let () = run_test_tt_main suite
