(** [Stop_log.record_stop_decision] (issue #3075): the per-trade stop columns
    follow the level the stop machine actually held, not only what transitions
    reported. *)

open OUnit2
open Core
open Trading_strategy
open Matchers
module Stop_log = Backtest.Stop_log

let _pid = "AAON-wein-951"
let _date = Date.of_string "2024-02-15"

let _risk_params stop_loss_price : Position.risk_params =
  { stop_loss_price; take_profit_price = None; max_hold_days = None }

let _transition kind : Position.transition =
  { position_id = _pid; date = _date; kind }

let _create_entering =
  _transition
    (CreateEntering
       {
         symbol = "AAON";
         side = Long;
         target_quantity = 100.0;
         entry_price = 83.42;
         reasoning = ManualDecision { description = "test" };
       })

let _entry_complete_no_stop =
  _transition (EntryComplete { risk_params = _risk_params None })

let _update_stop level =
  _transition (UpdateRiskParams { new_risk_params = _risk_params (Some level) })

(* One step of the drive: a transition the strategy returned, or a stop-machine
   decision the strategy reported through its audit recorder. *)
type step =
  | Trans of Position.transition
  | Decision of float * float
  | Split of float
      (** The strategy rescaled the stop for a split by this factor (#3127). *)

(* Book [installed] the way the entry-decision audit does, then replay
   [steps] in order, and return the position's single [stop_info]. *)
let _run ~installed steps : Stop_log.stop_info =
  let log = Stop_log.create () in
  Stop_log.record_installed_stop log ~position_id:_pid ~symbol:"AAON"
    ~level:installed;
  List.iter steps ~f:(function
    | Trans t -> Stop_log.record_transitions log [ t ]
    | Decision (stop_before, stop_after) ->
        Stop_log.record_stop_decision log ~position_id:_pid ~stop_before
          ~stop_after
    | Split factor -> Stop_log.record_stop_split log ~position_id:_pid ~factor);
  match Stop_log.get_stop_infos log with
  | [ info ] -> info
  | infos ->
      assert_failure
        (Printf.sprintf "expected exactly one stop_info, got %d"
           (List.length infos))

let _columns ~entry_stop ~max_stop ~exit_stop ~n_stop_raises =
  all_of
    [
      field
        (fun (i : Stop_log.stop_info) -> i.entry_stop)
        (is_some_and (float_equal entry_stop));
      field
        (fun (i : Stop_log.stop_info) -> i.max_stop)
        (is_some_and (float_equal max_stop));
      field
        (fun (i : Stop_log.stop_info) -> i.exit_stop)
        (is_some_and (float_equal exit_stop));
      field
        (fun (i : Stop_log.stop_info) -> i.n_stop_raises)
        (equal_to n_stop_raises);
    ]

(* The AAON-wein-951 shape. The ticket was decided with a stop of 83.21, rested
   across a 3:2 split, and the machine held 55.475 (83.21 x 2/3) at the fill.
   The two later raises then move it to 72.15 and 79.18. Before #3075 the
   columns read entry 83.21 / max 83.21 / exit 79.18 / 1 raise. *)
let test_rested_ticket_split_reseeds_entry_stop _ =
  assert_that
    (_run ~installed:83.21
       [
         Trans _create_entering;
         Trans _entry_complete_no_stop;
         Decision (55.475, 55.475);
         Decision (55.475, 72.15);
         Trans (_update_stop 72.15);
         Decision (72.15, 79.18);
         Trans (_update_stop 79.18);
       ])
    (_columns ~entry_stop:55.475 ~max_stop:79.18 ~exit_stop:79.18
       ~n_stop_raises:2)

(* The common case: the machine holds the decision-time install at the fill.
   The columns are what they were before #3075. *)
let test_seed_equal_to_install_changes_nothing _ =
  assert_that
    (_run ~installed:142.50
       [
         Trans _create_entering;
         Trans _entry_complete_no_stop;
         Decision (142.50, 142.50);
         Decision (142.50, 148.00);
         Trans (_update_stop 148.00);
       ])
    (_columns ~entry_stop:142.50 ~max_stop:148.00 ~exit_stop:148.00
       ~n_stop_raises:1)

(* A 2:1 split while held: the next decision shows the machine at half the
   level, with no transition. [exit_stop] takes the post-split level, and
   [max_stop] and [entry_stop] are rescaled with it (#3127), so no stop column
   sits on the pre-split basis. *)
let test_split_while_held_rescales_exit_and_max _ =
  assert_that
    (_run ~installed:30.00
       [
         Trans _create_entering;
         Trans _entry_complete_no_stop;
         Decision (30.00, 30.00);
         Decision (30.00, 36.00);
         Trans (_update_stop 36.00);
         Decision (18.00, 18.00);
       ])
    (_columns ~entry_stop:15.00 ~max_stop:18.00 ~exit_stop:18.00
       ~n_stop_raises:1)

(* The CTO-2021 shape (#3127): installed 50.38 at the fill, a 3:1 split while
   held, then a raise to 18.49 on the post-split basis. Before #3127 the row
   read entry_stop 50.38 beside an entry price restated to 19.48. *)
let test_cto_split_while_held_restates_entry_stop _ =
  assert_that
    (_run ~installed:50.38
       [
         Trans _create_entering;
         Trans _entry_complete_no_stop;
         Decision (50.38, 50.38);
         Decision (50.38 /. 3.0, 18.49);
         Trans (_update_stop 18.49);
       ])
    (_columns ~entry_stop:(50.38 /. 3.0) ~max_stop:18.49 ~exit_stop:18.49
       ~n_stop_raises:1)

(* A move the machine made outside a decision (e.g. the late-Stage-2 tighten)
   shows up as a higher [stop_before] before its transition arrives. It counts
   once, whichever source reports it first. *)
let test_unreported_raise_counts_once _ =
  assert_that
    (_run ~installed:100.00
       [
         Trans _create_entering;
         Trans _entry_complete_no_stop;
         Decision (100.00, 100.00);
         Decision (106.00, 106.00);
         Trans (_update_stop 106.00);
       ])
    (_columns ~entry_stop:100.00 ~max_stop:106.00 ~exit_stop:106.00
       ~n_stop_raises:1)

(* trades.csv rows (#3127) ----------------------------------------------- *)

let _price_columns = [ "entry_price"; "exit_price"; "entry_stop"; "exit_stop" ]

(* Render one AAON-keyed round-trip with [info] through the real [trades.csv]
   writer and read back the four price columns by name. [entry_price] is given
   already restated onto the exit basis, as the round-trip extractor writes it. *)
let _row ~(info : Stop_log.stop_info) ~entry_price ~exit_price =
  let trade : Trading_simulation.Metrics.trade_metrics =
    {
      symbol = "AAON";
      side = Trading_base.Types.Buy;
      entry_date = _date;
      exit_date = Date.add_days _date 60;
      days_held = 60;
      entry_price;
      exit_price;
      quantity = 100.0;
      pnl_dollars = 0.0;
      pnl_percent = 0.0;
      position_id = Some _pid;
    }
  in
  let dir = Filename_unix.temp_dir "stop_log_basis" "" in
  let path = dir ^ "/trades.csv" in
  Exn.protect
    ~f:(fun () ->
      Backtest.Trades_stream.write_all ~output_dir:dir
        { round_trips = [ trade ]; stop_infos = [ info ]; audit = [] };
      let lines = In_channel.read_lines path in
      let cells l = String.split l ~on:',' in
      let header = cells (List.hd_exn lines)
      and row = cells (List.nth_exn lines 1) in
      List.map _price_columns ~f:(fun col ->
          let i, _ = List.findi_exn header ~f:(fun _ h -> String.equal h col) in
          List.nth_exn row i))
    ~finally:(fun () ->
      Core_unix.remove path;
      Core_unix.rmdir dir)

let _cents = Printf.sprintf "%.2f"

(* The CTO-2021 row: a 3:1 split while held. Every stop column is on the
   post-split basis the entry price is restated onto (entry 19.48, stop 16.79),
   not entry_stop 50.38 beside it. *)
let test_cto_row_stop_columns_on_price_basis _ =
  let info =
    _run ~installed:50.38
      [
        Trans _create_entering;
        Trans _entry_complete_no_stop;
        Decision (50.38, 50.38);
        Decision (50.38 /. 3.0, 18.49);
        Trans (_update_stop 18.49);
      ]
  in
  assert_that
    (_row ~info ~entry_price:19.48 ~exit_price:18.49)
    (equal_to [ "19.48"; "18.49"; _cents (50.38 /. 3.0); "18.49" ])

(* The AAON-2024 row: the ticket rested across the 3:2 split and filled after
   it, so the fill (83.43) and the stop the machine held there (55.475, the
   #3075 reseed) are both post-split. The gap between them is the #3075
   unscaled-trigger defect's real economics, not a basis mix. *)
let test_aaon_row_stop_columns_on_fill_basis _ =
  let info =
    _run ~installed:83.21
      [
        Trans _create_entering;
        Trans _entry_complete_no_stop;
        Decision (55.475, 55.475);
        Decision (55.475, 72.15);
        Trans (_update_stop 72.15);
        Decision (72.15, 79.18);
        Trans (_update_stop 79.18);
      ]
  in
  assert_that
    (_row ~info ~entry_price:83.43 ~exit_price:79.18)
    (equal_to [ "83.43"; "79.18"; _cents 55.475; "79.18" ])

(* Explicit split events (#3127, remaining shapes) ------------------------ *)

(* The AVD-wein-175 shape: a 2:1 split while held and no stop decision between
   it and the exit. Without the split event every stop column stayed on the
   pre-split basis (entry 40, max 44, exit 44) beside a restated entry price.
   With it all three are halved, and the rescale is not a raise. *)
let _avd_steps =
  [
    Trans _create_entering;
    Trans _entry_complete_no_stop;
    Decision (40.00, 40.00);
    Decision (40.00, 44.00);
    Trans (_update_stop 44.00);
    Split 2.0;
  ]

let test_avd_split_without_decision_rescales_every_column _ =
  assert_that
    (_run ~installed:40.00 _avd_steps)
    (_columns ~entry_stop:20.00 ~max_stop:22.00 ~exit_stop:22.00
       ~n_stop_raises:1)

(* A 1:10 reverse split on a long moves the stop UP by the rescale. Before the
   split event the log read that as a raise (entry 2.00 pre-split, max and exit
   20.00, one raise). Now it is the same stop on a new basis: every column
   reads 20.00 and nothing counts as a raise. *)
let test_reverse_split_long_is_not_a_raise _ =
  assert_that
    (_run ~installed:2.00
       [
         Trans _create_entering;
         Trans _entry_complete_no_stop;
         Decision (2.00, 2.00);
         Split 0.1;
         Decision (2.00 /. 0.1, 2.00 /. 0.1);
       ])
    (_columns ~entry_stop:20.00 ~max_stop:20.00 ~exit_stop:20.00
       ~n_stop_raises:0)

(* The CTO shape with the split event arriving before the decision, as the
   strategy orders them: the decision then shows no gap, so the columns are
   rescaled once, not twice. *)
let test_cto_split_event_then_decision_rescales_once _ =
  assert_that
    (_run ~installed:50.38
       [
         Trans _create_entering;
         Trans _entry_complete_no_stop;
         Decision (50.38, 50.38);
         Split 3.0;
         Decision (50.38 /. 3.0, 18.49);
         Trans (_update_stop 18.49);
       ])
    (_columns ~entry_stop:(50.38 /. 3.0) ~max_stop:18.49 ~exit_stop:18.49
       ~n_stop_raises:1)

(* The AVD row through the real writer: entry price restated to the exit
   basis (25.10), exit 21.90, and every stop column on that basis too. *)
let test_avd_row_stop_columns_on_price_basis _ =
  assert_that
    (_row
       ~info:(_run ~installed:40.00 _avd_steps)
       ~entry_price:25.10 ~exit_price:21.90)
    (equal_to [ "25.10"; "21.90"; "20.00"; "22.00" ])

(* A split for a position the log has never seen is ignored: no row is created
   for it (it would read symbol "" with no stops), and the known position is
   untouched. *)
let test_split_for_unknown_position_is_ignored _ =
  let log = Stop_log.create () in
  Stop_log.record_installed_stop log ~position_id:_pid ~symbol:"AAON"
    ~level:40.00;
  Stop_log.record_stop_split log ~position_id:"UNSEEN-wein-9" ~factor:2.0;
  assert_that
    (Stop_log.get_stop_infos log)
    (elements_are
       [
         all_of
           [
             field
               (fun (i : Stop_log.stop_info) -> i.position_id)
               (equal_to _pid);
             field
               (fun (i : Stop_log.stop_info) -> i.entry_stop)
               (is_some_and (float_equal 40.00));
           ];
       ])

let suite =
  "Stop_log machine sync"
  >::: [
         "rested ticket across a split reseeds entry_stop at the fill"
         >:: test_rested_ticket_split_reseeds_entry_stop;
         "seed equal to the install changes nothing"
         >:: test_seed_equal_to_install_changes_nothing;
         "split while held rescales exit_stop and max_stop"
         >:: test_split_while_held_rescales_exit_and_max;
         "unreported raise counts once" >:: test_unreported_raise_counts_once;
         "split while held restates entry_stop (CTO, #3127)"
         >:: test_cto_split_while_held_restates_entry_stop;
         "trades.csv CTO row: stop columns on the price basis (#3127)"
         >:: test_cto_row_stop_columns_on_price_basis;
         "trades.csv AAON row: stop columns on the fill basis (#3127)"
         >:: test_aaon_row_stop_columns_on_fill_basis;
         "split without a later decision rescales every column (AVD, #3127)"
         >:: test_avd_split_without_decision_rescales_every_column;
         "reverse split on a long is not a raise (#3127)"
         >:: test_reverse_split_long_is_not_a_raise;
         "split event then decision rescales once (CTO, #3127)"
         >:: test_cto_split_event_then_decision_rescales_once;
         "trades.csv AVD row: stop columns on the price basis (#3127)"
         >:: test_avd_row_stop_columns_on_price_basis;
         "split for an unknown position is ignored (#3127)"
         >:: test_split_for_unknown_position_is_ignored;
       ]

let () = run_test_tt_main suite
