(** End-to-end regression for issue #2687: a stale force-exit's reason must
    reach [trades.csv]'s [exit_trigger] column.

    Before this fix {!Trading_simulation.Stale_exit_runner.tick} applied its
    [TriggerExit] / [ExitFill] / [ExitComplete] transitions internally, so
    [Simulator.dependencies.on_transitions] never observed them, {!Stop_log}
    recorded nothing, and every stale force-exit rendered as a BLANK
    [exit_trigger] cell — 7 such rows in the canonical 26y record, all of them
    cash-deal delistings the safety net happened to price correctly.

    That blankness is the reason this test exists: per
    [dev/plans/delisting-data-fix-2026-09-06.md] §"Principle: fallbacks are
    quality flags, not mechanisms", a stale force-exit is a data-quality signal
    that must be countable in the artifacts. An invisible fallback cannot be
    counted, so it cannot be fixed.

    Modelled on [test_margin_exit_observability.ml], which pins the same
    plumbing for the margin exits (#2057) — the composition under test is the
    one {!Backtest.Panel_runner} wires in production:
    [Simulator.create_deps ~on_transitions:(Stop_log.record_transitions
     stop_log)] plus the {!Backtest.Strategy_wrapper} interception. The final
    assertion goes one layer further than the margin file and renders the actual
    CSV via {!Backtest.Trades_stream.write_all}, because the blank cell — not
    the collector state — is what a reader of the record saw. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
module Position = Trading_strategy.Position
module Stop_log = Backtest.Stop_log
module Strategy_interface = Trading_strategy.Strategy_interface
module Trades_stream = Backtest.Trades_stream

let _date s = Date.of_string s
let _dead_symbol = "DTV"
let _live_symbol = "KEEP"
let _entry_price = 100.0
let _last_close = 120.0
let _quantity = 10.0
let _position_id = "DTV-stale"
let _start = _date "2024-01-02"

(* Long enough that the gap is unambiguous, short enough that the run window
   below covers it with room to spare. *)
let _exit_after_days = 10

let _make_bar ~date ~close =
  Types.Daily_price.
    {
      date;
      open_price = close;
      high_price = close;
      low_price = close;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
      active_through = None;
    }

let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

(* [_dead_symbol] prints two bars then stops for good — the delisting shape.
   [_live_symbol] prints every calendar day so the step loop always has a bar
   (the force-exit runner is a deliberate no-op on a bar-less day). *)
let _bar_table =
  [
    ( _dead_symbol,
      [
        _make_bar ~date:_start ~close:_entry_price;
        _make_bar ~date:(Date.add_days _start 1) ~close:_last_close;
      ] );
    ( _live_symbol,
      List.init 60 ~f:(fun i ->
          _make_bar ~date:(Date.add_days _start i) ~close:50.0) );
  ]

let _bars_for ~symbol =
  List.Assoc.find _bar_table symbol ~equal:String.equal
  |> Option.value ~default:[]

(* Exact-date [get_price]; unbounded [get_previous_bar] so the dead symbol keeps
   a visible last bar and the ORDINARY bar-dated force-exit path fires (the
   #2672 no-prior-bar extension stays off — this test is about the label, not
   about which selection path found the candidate). *)
let _adapter () =
  let get_price ~symbol ~date =
    _bars_for ~symbol
    |> List.find ~f:(fun (b : Types.Daily_price.t) -> Date.equal b.date date)
  in
  let get_previous_bar ~symbol ~date =
    _bars_for ~symbol
    |> List.filter ~f:(fun (b : Types.Daily_price.t) -> Date.( < ) b.date date)
    |> List.last
  in
  Trading_simulation_data.Market_data_adapter.create_with_callbacks ~get_price
    ~get_previous_bar

(* One-shot strategy: emits a single [CreateEntering] for [_dead_symbol] on its
   first call with a bar, then holds passively forever. Mirrors
   [test_margin_exit_observability.ml:_make_one_shot_strategy]. *)
let _one_shot_strategy () : (module Strategy_interface.STRATEGY) =
  let entered = ref false in
  let module S : Strategy_interface.STRATEGY = struct
    let name = "OneShotStale"

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      if !entered then Ok { Strategy_interface.transitions = [] }
      else
        match get_price _dead_symbol with
        | None -> Ok { Strategy_interface.transitions = [] }
        | Some (bar : Types.Daily_price.t) ->
            entered := true;
            let trans =
              {
                Position.position_id = _position_id;
                date = bar.date;
                kind =
                  Position.CreateEntering
                    {
                      symbol = _dead_symbol;
                      side = Position.Long;
                      target_quantity = _quantity;
                      entry_price = bar.close_price;
                      reasoning =
                        Position.TechnicalSignal
                          {
                            indicator = "stale-exit-observability-test";
                            description = "test entry";
                          };
                    };
              }
            in
            Ok { Strategy_interface.transitions = [ trans ] }
  end
  in
  (module S)

let _stale_policy ~stale_exit_after_days =
  {
    Trading_simulation.Stale_hold.enabled = true;
    stale_after_days = 5;
    stale_exit_after_days;
    exit_without_prior_bar = false;
  }

(* Run the simulator with the production wiring and return the populated
   [stop_log] alongside the run result. [stale_exit_after_days = None] is the
   pre-#1484 default arm: the detector still records but nothing force-exits. *)
let _run ~test_name ~stale_exit_after_days =
  let stop_log = Stop_log.create () in
  let strategy =
    Backtest.Strategy_wrapper.wrap ~stop_log (_one_shot_strategy ())
  in
  let result_ref = ref None in
  Test_helpers.with_test_data test_name
    [ (_dead_symbol, []); (_live_symbol, []) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps
          ~symbols:[ _dead_symbol; _live_symbol ]
          ~data_dir ~strategy ~commission:_commission
          ~market_data_adapter:(_adapter ())
          ~stale_hold_policy:(_stale_policy ~stale_exit_after_days)
          ~on_transitions:(Stop_log.record_transitions stop_log)
          ()
      in
      let config =
        {
          Trading_simulation_types.Simulator_types.start_date = _start;
          end_date = Date.add_days _start 40;
          initial_cash = 100_000.0;
          commission = _commission;
          strategy_cadence = Types.Cadence.Daily;
        }
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      match run sim with
      | Ok r -> result_ref := Some r
      | Error err -> assert_failure ("simulation failed: " ^ Status.show err));
  match !result_ref with
  | Some r -> (stop_log, r)
  | None -> assert_failure "run produced no result"

let _dead_stop_info stop_log =
  Stop_log.get_stop_infos stop_log
  |> List.find ~f:(fun (i : Stop_log.stop_info) ->
      String.equal i.position_id _position_id)

(** The collector half: an armed stale force-exit lands in {!Stop_log} as a
    [Strategy_signal] labelled ["stale_force_exit"], carrying the candidate's
    own gap detail. This is the value {!Backtest.Result_writer} reads for the
    [exit_trigger] column. *)
let test_stop_log_records_stale_force_exit_label _ =
  let stop_log, _ =
    _run ~test_name:"stale_exit_label"
      ~stale_exit_after_days:(Some _exit_after_days)
  in
  assert_that
    (Option.bind (_dead_stop_info stop_log) ~f:(fun i -> i.exit_trigger))
    (is_some_and
       (matching ~msg:"Expected a stale_force_exit Strategy_signal"
          (function
            | Stop_log.Strategy_signal { label; detail } -> Some (label, detail)
            | _ -> None)
          (all_of
             [
               field fst (equal_to "stale_force_exit");
               field snd
                 (is_some_and
                    (matching ~msg:"detail names the bar gap"
                       (fun d ->
                         if String.is_prefix d ~prefix:"last_bar_date=" then
                           Some ()
                         else None)
                       (equal_to ())));
             ])))

(** The R1 no-op arm: with the force-exit unarmed
    ([stale_exit_after_days = None], the default) the same run force-exits
    nothing, so the position is still open at the window end and carries no exit
    trigger at all. Without this the test above could pass on a collector that
    labels every position. *)
let test_unarmed_run_records_no_exit_trigger _ =
  let stop_log, _ =
    _run ~test_name:"stale_exit_unarmed" ~stale_exit_after_days:None
  in
  assert_that
    (Option.bind (_dead_stop_info stop_log) ~f:(fun i -> i.exit_trigger))
    is_none

(* ------------------------------------------------------------------ *)
(* The rendered CSV — the cell a reader of the record actually sees.    *)
(* ------------------------------------------------------------------ *)

let _rm_rf dir =
  (try
     Sys_unix.ls_dir dir
     |> List.iter ~f:(fun e -> Core_unix.remove (dir ^ "/" ^ e))
   with _ -> ());
  try Core_unix.rmdir dir with _ -> ()

(* The [exit_trigger] cell of the single [trades.csv] data row, addressed by
   header name per {!Backtest.Trades_csv_schema}. *)
let _exit_trigger_cell ~output_dir =
  let split line = String.split line ~on:',' in
  match In_channel.read_lines (output_dir ^ "/trades.csv") with
  | header :: row :: _ -> (
      match
        List.findi (split header) ~f:(fun _ c -> String.equal c "exit_trigger")
      with
      | None -> assert_failure "trades.csv has no exit_trigger column"
      | Some (i, _) -> List.nth (split row) i)
  | _ -> assert_failure "trades.csv has no data row"

(** The rendering half, and the actual #2687 symptom: the round trip the stale
    force-exit closed renders ["stale_force_exit"] in [trades.csv], not the
    blank cell the record carried. Joins the collector's [stop_info] to the
    extracted round-trip exactly as {!Backtest.Result_writer} does, through
    {!Backtest.Trades_stream.write_all}. *)
let test_trades_csv_renders_the_stale_force_exit_label _ =
  let stop_log, result =
    _run ~test_name:"stale_exit_csv"
      ~stale_exit_after_days:(Some _exit_after_days)
  in
  let round_trips =
    Trading_simulation.Metrics.extract_round_trips result.steps
    |> List.filter ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
        String.equal t.symbol _dead_symbol)
  in
  let output_dir = Filename_unix.temp_dir "stale_exit_csv" "" in
  Exn.protect
    ~f:(fun () ->
      Trades_stream.write_all ~output_dir
        {
          round_trips;
          stop_infos = Stop_log.get_stop_infos stop_log;
          audit = [];
          force_liquidations = [];
        };
      assert_that
        (_exit_trigger_cell ~output_dir)
        (is_some_and (equal_to "stale_force_exit")))
    ~finally:(fun () -> _rm_rf output_dir)

let suite =
  "stale_exit_observability"
  >::: [
         "stop_log records the stale_force_exit label"
         >:: test_stop_log_records_stale_force_exit_label;
         "unarmed run records no exit trigger"
         >:: test_unarmed_run_records_no_exit_trigger;
         "trades.csv renders the stale_force_exit label"
         >:: test_trades_csv_renders_the_stale_force_exit_label;
       ]

let () = run_test_tt_main suite
