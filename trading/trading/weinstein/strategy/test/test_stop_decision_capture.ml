(** Issue #2977 — {!Stops_runner.update}'s [?on_stop_decision] sink.

    Three contracts, all through the real runner (empty bar reader, so the MA is
    the close and the stage is the warmup Stage 2 + Rising default):

    - {b Sampling.} Under the default [Daily] cadence a rare decision (here the
      seed) is emitted on the day it happens; the frequent holds only on the
      Friday tick.
    - {b Siblings.} Two positions on one ticker share one advance but each gets
      its own record, keyed by its own position id.
    - {b Observability only.} Passing the sink changes neither the returned
      transitions nor the stop states. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module D = Weinstein_stops.Stop_decision

let ticker = "AAPL"

let make_bar date ~low ~close =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = close;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* Mon 2024-01-08 .. Fri 2024-01-12, creeping 100 -> 104: never an 8% pullback
   from the running peak to the 99 seed low. *)
let week =
  [
    make_bar "2024-01-08" ~low:99.0 ~close:100.0;
    make_bar "2024-01-09" ~low:100.0 ~close:101.0;
    make_bar "2024-01-10" ~low:101.0 ~close:102.0;
    make_bar "2024-01-11" ~low:102.0 ~close:103.0;
    make_bar "2024-01-12" ~low:103.0 ~close:104.0;
  ]

(** A long [Holding] on [ticker] with position id [id]. *)
let make_holding id =
  let make_trans kind =
    { Trading_strategy.Position.position_id = id; date = Date.of_string "2024-01-05"; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> OUnit2.assert_failure "position setup failed"
  in
  let open Trading_strategy.Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = ticker;
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = 100.0;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = 100.0 }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let positions_of ids =
  String.Map.of_alist_exn (List.map ids ~f:(fun id -> (id, make_holding id)))

(** Drive the runner over [bars], threading stop state. Returns the per-bar
    [(exits, adjusts)] and the final stop states. *)
let run ?on_stop_decision ~ids bars =
  let stop_states =
    ref
      (String.Map.singleton ticker
         (Weinstein_stops.Initial { stop_level = 90.0; reference_level = 90.0 }))
  in
  let prior_stages = Hashtbl.create (module String) in
  let transitions =
    List.map bars ~f:(fun (bar : Types.Daily_price.t) ->
        Stops_runner.update ?on_stop_decision
          ~stops_config:Weinstein_stops.default_config
          ~stage_config:Stage.default_config ~lookback_bars:52
          ~positions:(positions_of ids)
          ~get_price:(fun s -> if String.equal s ticker then Some bar else None)
          ~stop_states ~bar_reader:(Bar_reader.empty ()) ~as_of:bar.date
          ~prior_stages ())
  in
  (transitions, Map.data !stop_states)

let captured_decisions ~ids bars =
  let captured = ref [] in
  let _ : _ =
    run ~on_stop_decision:(fun d -> captured := d :: !captured) ~ids bars
  in
  List.rev !captured

let test_daily_cadence_emits_seed_and_friday_hold _ =
  assert_that
    (captured_decisions ~ids:[ ticker ] week)
    (elements_are
       [
         all_of
           [
             field (fun (d : D.t) -> d.date) (equal_to (Date.of_string "2024-01-08"));
             field (fun (d : D.t) -> d.reason) (equal_to D.Seeded_trailing);
           ];
         all_of
           [
             field (fun (d : D.t) -> d.date) (equal_to (Date.of_string "2024-01-12"));
             field (fun (d : D.t) -> d.reason) (equal_to D.No_correction_yet);
             field (fun (d : D.t) -> d.stop_after) (float_equal 90.0);
           ];
       ])

let test_sibling_positions_each_get_a_record _ =
  assert_that
    (captured_decisions ~ids:[ "AAPL-1"; "AAPL-2" ] [ List.hd_exn week ])
    (elements_are
       [
         field (fun (d : D.t) -> d.position_id) (equal_to "AAPL-1");
         field (fun (d : D.t) -> d.position_id) (equal_to "AAPL-2");
       ])

let test_sink_changes_no_decision _ =
  assert_that
    (run ~on_stop_decision:(fun _ -> ()) ~ids:[ ticker ] week)
    (equal_to (run ~ids:[ ticker ] week))

let suite =
  "Stop_decision_capture"
  >::: [
         "daily cadence emits the seed and the Friday hold"
         >:: test_daily_cadence_emits_seed_and_friday_hold;
         "sibling positions each get a record"
         >:: test_sibling_positions_each_get_a_record;
         "the sink changes no decision" >:: test_sink_changes_no_decision;
       ]

let () = run_test_tt_main suite
