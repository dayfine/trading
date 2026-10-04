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
type step = Trans of Position.transition | Decision of float * float

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
          ~stop_after);
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
   level, with no transition. [exit_stop] takes the post-split level and
   [max_stop] is rescaled with it, so it never sits on the pre-split basis. *)
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
    (_columns ~entry_stop:30.00 ~max_stop:18.00 ~exit_stop:18.00
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
       ]

let () = run_test_tt_main suite
