(** Tests for {!Weinstein_strategy.Stop_move_capture} — the silent stop-move
    feed behind [trades.csv]'s [n_stop_raises] / [max_stop] (issue #2974). *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _date = Date.of_string "2024-03-15"

let _make_trans ~id kind =
  { Trading_strategy.Position.position_id = id; date = _date; kind }

let _unwrap = function
  | Ok p -> p
  | Error _ -> assert_failure "position setup failed"

let _entering ~id ~ticker =
  let open Trading_strategy.Position in
  create_entering
    (_make_trans ~id
       (CreateEntering
          {
            symbol = ticker;
            side = Trading_base.Types.Long;
            target_quantity = 10.0;
            entry_price = 100.0;
            reasoning = ManualDecision { description = "test" };
          }))
  |> _unwrap

(* A long in [Holding], reached through the same fill / complete transitions
   the simulator applies — so its [risk_params] carry no stop, as in a run. *)
let _holding ~id ~ticker =
  let open Trading_strategy.Position in
  let p =
    apply_transition (_entering ~id ~ticker)
      (_make_trans ~id
         (EntryFill { filled_quantity = 10.0; fill_price = 100.0 }))
    |> _unwrap
  in
  apply_transition p
    (_make_trans ~id
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> _unwrap

let _positions ps =
  String.Map.of_alist_exn
    (List.map ps ~f:(fun (p : Trading_strategy.Position.t) -> (p.id, p)))

let _initial level =
  Weinstein_stops.Initial { stop_level = level; reference_level = level }

let _tightened level =
  Weinstein_stops.Tightened
    { stop_level = level; last_correction_extreme = level; reason = "test" }

let _states alist = String.Map.of_alist_exn alist

let _adjust ~id level =
  let open Trading_strategy.Position in
  _make_trans ~id
    (UpdateRiskParams
       {
         new_risk_params =
           {
             stop_loss_price = Some level;
             take_profit_price = None;
             max_hold_days = None;
           };
       })

let _moves ?(reported = []) ~positions ~before ~after () =
  Stop_move_capture.silent_moves ~positions ~before ~after ~reported
    ~current_date:_date

(* The #2974 case: the machine tightened the stop (95 -> 99) and emitted no
   transition — the move is reported at the new level. *)
let test_tightening_without_transition_is_reported _ =
  assert_that
    (_moves
       ~positions:(_positions [ _holding ~id:"p1" ~ticker:"AAPL" ])
       ~before:(_states [ ("AAPL", _initial 95.0) ])
       ~after:(_states [ ("AAPL", _tightened 99.0) ])
       ())
    (elements_are
       [
         all_of
           [
             field
               (fun (e : Audit_recorder.stop_move_event) -> e.position_id)
               (equal_to "p1");
             field
               (fun (e : Audit_recorder.stop_move_event) -> e.symbol)
               (equal_to "AAPL");
             field
               (fun (e : Audit_recorder.stop_move_event) -> e.date)
               (equal_to _date);
             field
               (fun (e : Audit_recorder.stop_move_event) -> e.stop_level)
               (float_equal 99.0);
           ];
       ])

(* A move the runner already reported as an adjust is not reported twice. *)
let test_move_with_adjust_transition_is_not_reported _ =
  assert_that
    (_moves
       ~reported:[ _adjust ~id:"p1" 99.0 ]
       ~positions:(_positions [ _holding ~id:"p1" ~ticker:"AAPL" ])
       ~before:(_states [ ("AAPL", _initial 95.0) ])
       ~after:(_states [ ("AAPL", _tightened 99.0) ])
       ())
    (size_is 0)

(* A state change that leaves the level where it was (e.g. tightening whose
   candidate did not beat the resting stop) is not a move. *)
let test_unchanged_level_is_not_reported _ =
  assert_that
    (_moves
       ~positions:(_positions [ _holding ~id:"p1" ~ticker:"AAPL" ])
       ~before:(_states [ ("AAPL", _initial 95.0) ])
       ~after:(_states [ ("AAPL", _tightened 95.0) ])
       ())
    (size_is 0)

(* Only holdings own a move: an entering sibling on the same ticker, and a
   ticker with no prior state, produce nothing. *)
let test_non_holding_and_unseeded_are_skipped _ =
  assert_that
    (_moves
       ~positions:
         (_positions
            [
              _entering ~id:"p2" ~ticker:"AAPL";
              _holding ~id:"p3" ~ticker:"MSFT";
            ])
       ~before:(_states [ ("AAPL", _initial 95.0) ])
       ~after:(_states [ ("AAPL", _tightened 99.0); ("MSFT", _tightened 50.0) ])
       ())
    (size_is 0)

(* [emit] hands each event to the recorder's [record_stop_move]. *)
let test_emit_feeds_recorder _ =
  let captured = ref [] in
  let audit_recorder : Audit_recorder.t =
    {
      Audit_recorder.noop with
      record_stop_move = (fun e -> captured := e :: !captured);
    }
  in
  Stop_move_capture.emit ~audit_recorder
    ~positions:(_positions [ _holding ~id:"p1" ~ticker:"AAPL" ])
    ~before:(_states [ ("AAPL", _initial 95.0) ])
    ~after:(_states [ ("AAPL", _tightened 99.0) ])
    ~reported:[] ~current_date:_date;
  assert_that !captured
    (elements_are
       [
         field
           (fun (e : Audit_recorder.stop_move_event) -> e.stop_level)
           (float_equal 99.0);
       ])

let suite =
  "Stop_move_capture"
  >::: [
         "tightening without a transition is reported"
         >:: test_tightening_without_transition_is_reported;
         "move with an adjust transition is not reported"
         >:: test_move_with_adjust_transition_is_not_reported;
         "unchanged level is not reported"
         >:: test_unchanged_level_is_not_reported;
         "non-holding and unseeded positions are skipped"
         >:: test_non_holding_and_unseeded_are_skipped;
         "emit feeds the recorder" >:: test_emit_feeds_recorder;
       ]

let () = run_test_tt_main suite
