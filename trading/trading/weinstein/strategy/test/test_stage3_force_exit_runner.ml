open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date ~close ?low ?high () =
  let low = Option.value low ~default:(close *. 0.99) in
  let high = Option.value high ~default:(close *. 1.01) in
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
  }

let stage3 = Weinstein_types.Stage3 { weeks_topping = 1 }
let stage2 = Weinstein_types.Stage2 { weeks_advancing = 5; late = false }
let cfg_k2 = { Stage3_force_exit.hysteresis_weeks = 2 }

(** Build a Position.t in the Holding state for [ticker] at [price]. Mirrors the
    helper in [test_stops_runner.ml] but exposes only the fields the Stage-3
    runner reads. *)
let make_holding_pos ?(side = Trading_base.Types.Long) ticker price date =
  let pos_id = ticker in
  let make_trans kind =
    { Trading_strategy.Position.position_id = pos_id; date; kind }
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
              side;
              target_quantity = 10.0;
              entry_price = price;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = price }))
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

let get_price_of bars symbol = List.Assoc.find bars symbol ~equal:String.equal
let _friday = Date.of_string "2024-01-05" (* Friday *)
let _monday = Date.of_string "2024-01-08" (* Monday *)

(* ------------------------------------------------------------------ *)
(* Off-cadence: non-Friday is a no-op                                   *)
(* ------------------------------------------------------------------ *)

let test_non_friday_no_op _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  Hashtbl.set stage3_streaks ~key:"AAPL" ~data:1;
  let exits =
    Stage3_force_exit_runner.update ~config:cfg_k2 ~is_screening_day:false
      ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-08" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_monday
  in
  assert_that exits is_empty;
  (* Non-Friday call must not advance the streak counter. *)
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 1))

(* ------------------------------------------------------------------ *)
(* Empty positions: no exits                                            *)
(* ------------------------------------------------------------------ *)

let test_empty_positions_returns_empty _ =
  let exits =
    Stage3_force_exit_runner.update ~config:cfg_k2 ~is_screening_day:true
      ~positions:String.Map.empty ~get_price:(get_price_of [])
      ~prior_stages:(Hashtbl.create (module String))
      ~stage3_streaks:(Hashtbl.create (module String))
      ~stop_exit_position_ids:String.Set.empty ~current_date:_friday
  in
  assert_that exits is_empty

(* ------------------------------------------------------------------ *)
(* Long position: Stage 3 below hysteresis → no exit                    *)
(* ------------------------------------------------------------------ *)

let test_stage3_below_hysteresis_no_exit _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  let exits =
    Stage3_force_exit_runner.update ~config:cfg_k2 ~is_screening_day:true
      ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday
  in
  (* First Stage-3 read brings streak to 1 < hysteresis_weeks = 2. *)
  assert_that exits is_empty;
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 1))

(* ------------------------------------------------------------------ *)
(* Long position: Stage 3 at hysteresis → exit emitted                  *)
(* ------------------------------------------------------------------ *)

let test_stage3_at_hysteresis_emits_exit _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  Hashtbl.set stage3_streaks ~key:"AAPL" ~data:1;
  (* prior streak = 1 — second Stage-3 read fires *)
  let bar = make_bar "2024-01-05" ~close:97.5 () in
  let exits =
    Stage3_force_exit_runner.update ~config:cfg_k2 ~is_screening_day:true
      ~positions
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday
  in
  assert_that exits
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_strategy.Position.transition) -> t.position_id)
               (equal_to "AAPL");
             field
               (fun (t : Trading_strategy.Position.transition) -> t.date)
               (equal_to _friday);
             field
               (fun (t : Trading_strategy.Position.transition) -> t.kind)
               (matching
                  ~msg:
                    "Expected TriggerExit with StrategySignal stage3_force_exit"
                  (function
                    | Trading_strategy.Position.TriggerExit
                        {
                          exit_reason =
                            Trading_strategy.Position.StrategySignal
                              { label; detail };
                          exit_price;
                        } ->
                        Some (label, detail, exit_price)
                    | _ -> None)
                  (all_of
                     [
                       field (fun (l, _, _) -> l) (equal_to "stage3_force_exit");
                       field
                         (fun (_, d, _) -> d)
                         (is_some_and (equal_to "weeks_in_stage3=2"));
                       field (fun (_, _, p) -> p) (float_equal 97.5);
                     ]));
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Short position: never triggers Stage 3 force exit                    *)
(* ------------------------------------------------------------------ *)

let test_short_position_never_emits_exit _ =
  let pos =
    make_holding_pos ~side:Trading_base.Types.Short "AAPL" 100.0 _friday
  in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  (* Pre-seed the streak above the threshold to make sure even a streak that
     would fire on a long is suppressed for a short. *)
  Hashtbl.set stage3_streaks ~key:"AAPL" ~data:5;
  let exits =
    Stage3_force_exit_runner.update ~config:cfg_k2 ~is_screening_day:true
      ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday
  in
  assert_that exits is_empty;
  (* Streak counter stays at the pre-seeded 5 — the runner does not advance
     state for shorts. *)
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 5))

(* ------------------------------------------------------------------ *)
(* Stop-out collision: position already exited via stops is skipped     *)
(* ------------------------------------------------------------------ *)

let test_skips_position_already_stop_exited _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  Hashtbl.set stage3_streaks ~key:"AAPL" ~data:1;
  let stop_exit_position_ids = String.Set.singleton pos.id in
  let exits =
    Stage3_force_exit_runner.update ~config:cfg_k2 ~is_screening_day:true
      ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids
      ~current_date:_friday
  in
  assert_that exits is_empty;
  (* Streak counter still advances even though the exit was suppressed —
     accurate accounting against the stage stream is kept. *)
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 2))

(* ------------------------------------------------------------------ *)
(* Symbol missing from prior_stages: no exit                            *)
(* ------------------------------------------------------------------ *)

let test_unknown_symbol_in_prior_stages_no_exit _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  let stage3_streaks = Hashtbl.create (module String) in
  let exits =
    Stage3_force_exit_runner.update ~config:cfg_k2 ~is_screening_day:true
      ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday
  in
  assert_that exits is_empty;
  (* Streak counter is not touched — there's no signal to record. *)
  assert_that (Hashtbl.find stage3_streaks "AAPL") is_none

(* ------------------------------------------------------------------ *)
(* Stage 2 read resets the streak                                       *)
(* ------------------------------------------------------------------ *)

let test_stage2_read_resets_streak _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage2;
  let stage3_streaks = Hashtbl.create (module String) in
  Hashtbl.set stage3_streaks ~key:"AAPL" ~data:7;
  (* prior streak = 7 *)
  let exits =
    Stage3_force_exit_runner.update ~config:cfg_k2 ~is_screening_day:true
      ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday
  in
  assert_that exits is_empty;
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 0))

(* ------------------------------------------------------------------ *)
(* No bar from get_price: position skipped (no exit)                   *)
(* ------------------------------------------------------------------ *)

let test_missing_bar_skips_position _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  Hashtbl.set stage3_streaks ~key:"AAPL" ~data:1;
  let exits =
    Stage3_force_exit_runner.update ~config:cfg_k2 ~is_screening_day:true
      ~positions
      ~get_price:(fun _ -> None)
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday
  in
  assert_that exits is_empty;
  (* Streak counter still advanced via observe_position. *)
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 2))

(* ------------------------------------------------------------------ *)
(* runner                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "stage3_force_exit_runner"
  >::: [
         "non-Friday is a no-op (does not advance streak)"
         >:: test_non_friday_no_op;
         "empty positions returns empty list"
         >:: test_empty_positions_returns_empty;
         "Stage 3 below hysteresis: no exit, streak advances to 1"
         >:: test_stage3_below_hysteresis_no_exit;
         "Stage 3 at hysteresis: emits TriggerExit with \
          StrategySignal(stage3_force_exit)"
         >:: test_stage3_at_hysteresis_emits_exit;
         "short position never emits exit, streak counter not touched"
         >:: test_short_position_never_emits_exit;
         "stops-already-exited position is skipped (streak still advances)"
         >:: test_skips_position_already_stop_exited;
         "symbol missing from prior_stages: no exit, streak unchanged"
         >:: test_unknown_symbol_in_prior_stages_no_exit;
         "Stage 2 read resets streak to 0" >:: test_stage2_read_resets_streak;
         "missing bar from get_price: no exit, streak still advances"
         >:: test_missing_bar_skips_position;
       ]

let () = run_test_tt_main suite
