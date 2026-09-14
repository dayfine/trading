(** End-to-end regression: a force-liquidation (drawdown-breaker) exit must
    reach [trades.csv]'s [exit_trigger] column as ["force_liquidation"].

    Before 2026-09-14 {!Weinstein_strategy.Force_liquidation_runner} stamped its
    [TriggerExit] with a [Position.StopLoss] [exit_reason], on the reasoning
    that the force-liquidation distinction "is recorded separately via the audit
    recorder". {!Backtest.Trades_stream} was supposed to close the loop by
    re-labelling any row whose [(symbol, exit_date)] matched a recorded event —
    but that join keys on the date the breaker {e fired}, and exits fill on the
    {e following} bar, so it could not hit. Measured 2026-09-13 on the 26y
    record: every breaker exit read as ["stop_loss"] (2-3 per null cell, 5-6 per
    wide-stop cell) and zero rows anywhere carried a force-liquidation label, so
    exit-mix reads silently undercounted the breaker.

    That invisibility is the reason this test exists. Per
    [dev/plans/delisting-data-fix-2026-09-06.md] §"Principle: fallbacks are
    quality flags, not mechanisms", a breaker exit is evidence the primary stop
    machinery failed to protect the trade — [force_liquidation_log.mli] says so
    in as many words. An uncountable fallback cannot be triaged.

    The composition under test is the production one, minus the simulator: the
    real {!Weinstein_strategy.Force_liquidation_runner} produces the transition,
    {!Backtest.Stop_log} observes it exactly as
    [Simulator.create_deps ~on_transitions] wires it, and
    {!Backtest.Trades_stream.write_all} renders the actual CSV — because the
    rendered cell, not the collector state, is what a reader of the record saw.
    Modelled on [test_stale_exit_observability.ml], which pins the same plumbing
    for the stale safety net (#2687). *)

open OUnit2
open Core
open Matchers
module Position = Trading_strategy.Position
module Stop_log = Backtest.Stop_log
module Trades_stream = Backtest.Trades_stream
module FL = Portfolio_risk.Force_liquidation
module Runner = Weinstein_strategy.Force_liquidation_runner

let _date s = Date.of_string s
let _entry_date = _date "2024-01-02"
let _exit_date = _date "2024-04-29"

(* Entered at 100, marked at 40: a 60% loss, far past the default 25%
   per-position long threshold, so the breaker fires unambiguously. *)
let _entry_price = 100.0
let _crash_price = 40.0
let _quantity = 100.0

let _make_bar ~date ~close =
  Types.Daily_price.
    {
      date;
      open_price = close;
      high_price = close *. 1.01;
      low_price = close *. 0.99;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
      active_through = None;
    }

(** Build a [Holding] position through the canonical entry chain, so the input
    to the runner is bit-equal to what the simulator would have produced. *)
let _make_holding ~symbol ~position_id =
  let unwrap = function
    | Ok p -> p
    | Error err -> assert_failure ("position setup failed: " ^ Status.show err)
  in
  let trans kind = { Position.position_id; date = _entry_date; kind } in
  Position.create_entering
    (trans
       (Position.CreateEntering
          {
            symbol;
            side = Trading_base.Types.Long;
            target_quantity = _quantity;
            entry_price = _entry_price;
            reasoning =
              Position.TechnicalSignal
                { indicator = "test"; description = "breaker-entry" };
          }))
  |> unwrap
  |> fun p ->
  Position.apply_transition p
    (trans
       (Position.EntryFill
          { filled_quantity = _quantity; fill_price = _entry_price }))
  |> unwrap
  |> fun p ->
  Position.apply_transition p
    (trans
       (Position.EntryComplete
          {
            risk_params =
              {
                stop_loss_price = Some 95.0;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

(** The round-trip the simulator would have emitted for a closed position. The
    money columns are inputs here — this file pins the LABEL, and the rest of
    the suite (goldens included) pins the P&L. *)
let _round_trip ~symbol ~position_id : Trading_simulation.Metrics.trade_metrics
    =
  {
    symbol;
    side = Trading_base.Types.Buy;
    entry_date = _entry_date;
    exit_date = _exit_date;
    days_held = Date.diff _exit_date _entry_date;
    entry_price = _entry_price;
    exit_price = _crash_price;
    quantity = _quantity;
    pnl_dollars = (_crash_price -. _entry_price) *. _quantity;
    pnl_percent = (_crash_price -. _entry_price) /. _entry_price *. 100.0;
    position_id = Some position_id;
  }

(** Run the breaker over [positions], feed every transition it emits to a fresh
    {!Stop_log} exactly as the simulator's [on_transitions] hook does, and
    return that log. The positions themselves are the only setup: no stop-out
    transitions are injected, so anything in the log came from the breaker. *)
let _stop_log_after_breaker ~positions ~get_price =
  let stop_log = Stop_log.create () in
  Stop_log.set_current_date stop_log _exit_date;
  let transitions =
    Runner.update ~config:FL.default_config ~positions ~get_price
      ~cash:1_000_000.0 ~current_date:_exit_date
      ~peak_tracker:(FL.Peak_tracker.create ())
      ~audit_recorder:Weinstein_strategy.Audit_recorder.noop
  in
  Stop_log.record_transitions stop_log transitions;
  stop_log

let _rm_rf dir =
  let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
  ()

(** Render [round_trips] against [stop_log] and return the [exit_trigger] cell
    of each row, in file order. *)
let _exit_trigger_cells ~stop_log ~round_trips =
  let dir = Core_unix.mkdtemp "/tmp/force_liq_observability_" in
  Fun.protect
    ~finally:(fun () -> _rm_rf dir)
    (fun () ->
      Trades_stream.write_all ~output_dir:dir
        {
          round_trips;
          stop_infos = Stop_log.get_stop_infos stop_log;
          audit = [];
        };
      let lines = In_channel.read_lines (dir ^ "/trades.csv") in
      match lines with
      | header :: rows ->
          let cols = String.split header ~on:',' in
          let idx =
            match
              List.findi cols ~f:(fun _ n -> String.equal n "exit_trigger")
            with
            | Some (i, _) -> i
            | None -> assert_failure "exit_trigger column missing"
          in
          List.map rows ~f:(fun r -> List.nth_exn (String.split r ~on:',') idx)
      | [] -> assert_failure "trades.csv is empty")

(* ------------------------------------------------------------------ *)
(* The symptom: the rendered cell                                       *)
(* ------------------------------------------------------------------ *)

let test_breaker_exit_renders_force_liquidation_label _ =
  let position_id = "AAPL-breaker" in
  let positions =
    String.Map.singleton "AAPL" (_make_holding ~symbol:"AAPL" ~position_id)
  in
  let bar = _make_bar ~date:_exit_date ~close:_crash_price in
  let get_price s = if String.equal s "AAPL" then Some bar else None in
  let stop_log = _stop_log_after_breaker ~positions ~get_price in
  assert_that
    (_exit_trigger_cells ~stop_log
       ~round_trips:[ _round_trip ~symbol:"AAPL" ~position_id ])
    (elements_are [ equal_to Runner.exit_label ])

(* ------------------------------------------------------------------ *)
(* The join: position id, not (symbol, date)                            *)
(* ------------------------------------------------------------------ *)

(** Two positions in the same symbol close on the same date; only ONE of them is
    held when the breaker runs. The row for the other must stay unlabelled.

    This is the property the removed [(symbol, exit_date)] override could not
    have: its key could not tell two same-symbol round-trips apart, so a hit
    would have painted both. The label now rides the transition and joins on
    [position_id] — the only key that distinguishes them
    ([memory/feedback_position_id_is_the_only_join_key]). *)
let test_only_the_breakered_position_is_labelled _ =
  let breakered = "AAPL-breaker" in
  let untouched = "AAPL-untouched" in
  let positions =
    String.Map.singleton "AAPL"
      (_make_holding ~symbol:"AAPL" ~position_id:breakered)
  in
  let bar = _make_bar ~date:_exit_date ~close:_crash_price in
  let get_price s = if String.equal s "AAPL" then Some bar else None in
  let stop_log = _stop_log_after_breaker ~positions ~get_price in
  assert_that
    (_exit_trigger_cells ~stop_log
       ~round_trips:
         [
           _round_trip ~symbol:"AAPL" ~position_id:breakered;
           _round_trip ~symbol:"AAPL" ~position_id:untouched;
         ])
    (elements_are [ equal_to Runner.exit_label; equal_to "" ])

let suite =
  "force_liquidation_observability"
  >::: [
         "breaker exit renders force_liquidation in trades.csv"
         >:: test_breaker_exit_renders_force_liquidation_label;
         "only the breakered position id is labelled"
         >:: test_only_the_breakered_position_is_labelled;
       ]

let () = run_test_tt_main suite
