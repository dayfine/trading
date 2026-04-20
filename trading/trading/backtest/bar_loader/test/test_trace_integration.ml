(** Integration tests for Bar_loader's [trace_hook] callback — 3d.

    Covers the wire-up between [Bar_loader.promote] / [Bar_loader.demote] and
    the [Backtest.Trace.Phase] variants added in the same increment. The
    callback lets bar_loader stay independent of the [backtest] library (see
    [bar_loader.mli] §Tracer hook); the tests use a small adapter that maps
    [tier_op] → [Trace.Phase.t] and forwards to [Trace.record], mirroring the
    wiring 3e's runner will set up.

    Scope:
    - No-trace path: [promote] / [demote] without [?trace_hook] record zero
      phases in a separately-owned [Trace.t].
    - Summary promote emits one [Promote_summary] phase with [symbols_in] equal
      to the batch size.
    - Full promote emits one [Promote_full] phase (not two — the internal
      Metadata/Summary cascade inside [_promote_one_to_full] bypasses the outer
      wrapper by design).
    - Metadata promote is silent (the legacy [Load_bars] phase owns that cost).
    - Demote emits one [Demote] phase, even when the target tier causes no
      actual tier change.
    - Multiple calls produce records in insertion order. *)

open OUnit2
open Core
open Matchers
module Bar_loader = Bar_loader

(* Re-declare the phase_metrics record here with [@@deriving test_matcher] so
   [match_phase_metrics] generates exhaustive field matchers. Mirrors the
   production type; adding a field in production fails compilation here and
   forces the test to be updated. *)
type phase_metrics = Backtest.Trace.phase_metrics = {
  phase : Backtest.Trace.Phase.t;
  elapsed_ms : int;
  symbols_in : int option;
  symbols_out : int option;
  peak_rss_kb : int option;
  bar_loads : int option;
}
[@@deriving test_matcher]

(** {1 Fixture helpers} *)

let _mk_bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
  }

let _daily_series ~start_date ~n ~base ~step =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_date i in
      let close = base +. (step *. Float.of_int i) in
      _mk_bar ~date ~close)

let _ok_or_fail ~context = function
  | Ok v -> v
  | Error (err : Status.t) ->
      assert_failure (Printf.sprintf "%s: %s" context (Status.show err))

let _write_symbol ~data_dir ~symbol ~bars =
  let storage =
    Csv.Csv_storage.create ~data_dir symbol
    |> _ok_or_fail ~context:("Csv_storage.create " ^ symbol)
  in
  Csv.Csv_storage.save storage bars
  |> _ok_or_fail ~context:("Csv_storage.save " ^ symbol)

let _fresh_data_dir () =
  let dir = Filename_unix.temp_dir "bar_loader_trace_test_" "" in
  Fpath.v dir

(** Maps [Bar_loader.tier_op] to the matching [Backtest.Trace.Phase.t] and
    forwards to [Trace.record], threading through [symbols_in]. This is the
    adapter 3e's runner will set up — wiring it in the test makes the contract
    between the two modules explicit. *)
let _hook_forwarding_to trace : Bar_loader.trace_hook =
  {
    record =
      (fun ~tier_op ~symbols f ->
        let phase : Backtest.Trace.Phase.t =
          match tier_op with
          | Promote_to_summary -> Promote_summary
          | Promote_to_full -> Promote_full
          | Demote_op -> Demote
        in
        Backtest.Trace.record ~trace ~symbols_in:symbols phase f);
  }

(** Loader fixture: ~420 days of synthetic history for one stock + SPY. The
    120-day tails used by default Summary_config need at least ~210 daily bars
    to resolve Mansfield RS; 420 days covers both Summary (250d) and Full (1800d
    bounded to 420 here via full_config override) promotions. *)
let _fixture ?trace_hook () =
  let as_of = Date.create_exn ~y:2023 ~m:Dec ~d:29 in
  let history_days = 420 in
  let start_date = Date.add_days as_of (-history_days) in
  let data_dir = _fresh_data_dir () in
  let stock_bars =
    _daily_series ~start_date ~n:history_days ~base:100.0 ~step:1.0
  in
  let benchmark_bars =
    _daily_series ~start_date ~n:history_days ~base:100.0 ~step:1.0
  in
  _write_symbol ~data_dir ~symbol:"STOCK" ~bars:stock_bars;
  _write_symbol ~data_dir ~symbol:"SPY" ~bars:benchmark_bars;
  let sector_map = String.Table.create () in
  Hashtbl.set sector_map ~key:"STOCK" ~data:"Tech";
  let summary_config =
    { Bar_loader.Summary_compute.default_config with tail_days = history_days }
  in
  let full_config : Bar_loader.Full_compute.config =
    { tail_days = history_days }
  in
  let loader =
    Bar_loader.create ~data_dir ~sector_map ~universe:[ "STOCK" ]
      ~summary_config ~full_config ?trace_hook ()
  in
  (loader, as_of)

(** {1 Tests} *)

let test_no_hook_promote_is_silent _ =
  (* Loader built without ?trace_hook. A trace we own should stay empty
     across promote / demote calls — observable behaviour matches pre-hook. *)
  let loader, as_of = _fixture () in
  let trace = Backtest.Trace.create () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote Summary"
  in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote Full"
  in
  Bar_loader.demote loader ~symbols:[ "STOCK" ] ~to_:Metadata_tier;
  assert_that (Backtest.Trace.snapshot trace) (size_is 0)

let test_promote_summary_emits_one_phase _ =
  let trace = Backtest.Trace.create () in
  let hook = _hook_forwarding_to trace in
  let loader, as_of = _fixture ~trace_hook:hook () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote Summary"
  in
  assert_that
    (Backtest.Trace.snapshot trace)
    (elements_are
       [
         match_phase_metrics
           ~phase:(equal_to Backtest.Trace.Phase.Promote_summary)
           ~symbols_in:(equal_to (Some 1)) ~symbols_out:(equal_to None)
           ~peak_rss_kb:__
           ~elapsed_ms:(ge (module Int_ord) 0)
           ~bar_loads:__;
       ])

let test_promote_full_emits_one_phase _ =
  (* Full promote cascades through Summary internally, but that cascade
     bypasses the outer [promote] wrapper — so we see exactly one
     [Promote_full] record, not one-of-each. *)
  let trace = Backtest.Trace.create () in
  let hook = _hook_forwarding_to trace in
  let loader, as_of = _fixture ~trace_hook:hook () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote Full"
  in
  assert_that
    (Backtest.Trace.snapshot trace)
    (elements_are
       [
         match_phase_metrics
           ~phase:(equal_to Backtest.Trace.Phase.Promote_full)
           ~symbols_in:(equal_to (Some 1)) ~symbols_out:__ ~peak_rss_kb:__
           ~elapsed_ms:__ ~bar_loads:__;
       ])

let test_promote_metadata_is_silent _ =
  (* Metadata promotion is the legacy Load_bars path; the bar_loader tracer
     hook deliberately does not emit for it. *)
  let trace = Backtest.Trace.create () in
  let hook = _hook_forwarding_to trace in
  let loader, as_of = _fixture ~trace_hook:hook () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Metadata_tier ~as_of
    |> _ok_or_fail ~context:"promote Metadata"
  in
  assert_that (Backtest.Trace.snapshot trace) (size_is 0)

let test_demote_emits_one_phase _ =
  let trace = Backtest.Trace.create () in
  let hook = _hook_forwarding_to trace in
  let loader, as_of = _fixture ~trace_hook:hook () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote Full"
  in
  (* One Promote_full from setup; demote should append one Demote. *)
  Bar_loader.demote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier;
  assert_that
    (Backtest.Trace.snapshot trace)
    (elements_are
       [
         match_phase_metrics
           ~phase:(equal_to Backtest.Trace.Phase.Promote_full)
           ~symbols_in:(equal_to (Some 1)) ~symbols_out:__ ~peak_rss_kb:__
           ~elapsed_ms:__ ~bar_loads:__;
         match_phase_metrics
           ~phase:(equal_to Backtest.Trace.Phase.Demote)
           ~symbols_in:(equal_to (Some 1)) ~symbols_out:__ ~peak_rss_kb:__
           ~elapsed_ms:__ ~bar_loads:__;
       ])

let test_demote_noop_still_emits _ =
  (* Demote is traced by batch size of the input list, not by the count of
     symbols that actually changed tier. An already-at-target demote still
     appends a phase — the tracer reports what the runner asked for, not
     what materialized. *)
  let trace = Backtest.Trace.create () in
  let hook = _hook_forwarding_to trace in
  let loader, as_of = _fixture ~trace_hook:hook () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote Summary"
  in
  (* Already at Summary — demote to Summary is a no-op tier-wise. *)
  Bar_loader.demote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier;
  assert_that
    (Backtest.Trace.snapshot trace)
    (elements_are
       [
         match_phase_metrics
           ~phase:(equal_to Backtest.Trace.Phase.Promote_summary)
           ~symbols_in:(equal_to (Some 1)) ~symbols_out:__ ~peak_rss_kb:__
           ~elapsed_ms:__ ~bar_loads:__;
         match_phase_metrics
           ~phase:(equal_to Backtest.Trace.Phase.Demote)
           ~symbols_in:(equal_to (Some 1)) ~symbols_out:__ ~peak_rss_kb:__
           ~elapsed_ms:__ ~bar_loads:__;
       ])

let test_multiple_calls_in_insertion_order _ =
  (* Two promotes + one demote — verify the record order matches the call
     order and batch sizes propagate. *)
  let trace = Backtest.Trace.create () in
  let hook = _hook_forwarding_to trace in
  let loader, as_of = _fixture ~trace_hook:hook () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote Summary"
  in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote Full"
  in
  Bar_loader.demote loader ~symbols:[ "STOCK" ] ~to_:Metadata_tier;
  let phases =
    Backtest.Trace.snapshot trace
    |> List.map ~f:(fun (m : Backtest.Trace.phase_metrics) -> m.phase)
  in
  assert_that phases
    (elements_are
       [
         equal_to Backtest.Trace.Phase.Promote_summary;
         equal_to Backtest.Trace.Phase.Promote_full;
         equal_to Backtest.Trace.Phase.Demote;
       ])

let suite =
  "Bar_loader.trace_hook"
  >::: [
         "no hook → promote/demote silent" >:: test_no_hook_promote_is_silent;
         "promote Summary emits one phase"
         >:: test_promote_summary_emits_one_phase;
         "promote Full emits one phase" >:: test_promote_full_emits_one_phase;
         "promote Metadata is silent" >:: test_promote_metadata_is_silent;
         "demote emits one phase" >:: test_demote_emits_one_phase;
         "demote no-op still emits" >:: test_demote_noop_still_emits;
         "multiple calls in insertion order"
         >:: test_multiple_calls_in_insertion_order;
       ]

let () = run_test_tt_main suite
