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
    active_through = None;
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

(** Convenience wrapper around [Stage3_force_exit_runner.update] that supplies
    the no-margin-filter case used by every existing test in this file. The new
    [exit_margin_pct] / [prior_stage_ma_values] arguments default to values that
    short-circuit the margin gate ([0.0] / [None]) — i.e. the runner's behaviour
    is identical to the pre-margin signature. New tests that exercise the margin
    filter pass the values explicitly via [~exit_margin_pct] and
    [~prior_stage_ma_values]. *)
let run_runner ?(exit_margin_pct = 0.0) ?(prior_stage_ma_values = None) ~config
    ~is_screening_day ~positions ~get_price ~prior_stages ~stage3_streaks
    ~stop_exit_position_ids ~current_date () =
  Stage3_force_exit_runner.update ~config ~exit_margin_pct
    ~prior_stage_ma_values ~is_screening_day ~positions ~get_price ~prior_stages
    ~stage3_streaks ~stop_exit_position_ids ~current_date

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
    run_runner ~config:cfg_k2 ~is_screening_day:false ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-08" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_monday ()
  in
  assert_that exits is_empty;
  (* Non-Friday call must not advance the streak counter. *)
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 1))

(* ------------------------------------------------------------------ *)
(* Empty positions: no exits                                            *)
(* ------------------------------------------------------------------ *)

let test_empty_positions_returns_empty _ =
  let exits =
    run_runner ~config:cfg_k2 ~is_screening_day:true ~positions:String.Map.empty
      ~get_price:(get_price_of [])
      ~prior_stages:(Hashtbl.create (module String))
      ~stage3_streaks:(Hashtbl.create (module String))
      ~stop_exit_position_ids:String.Set.empty ~current_date:_friday ()
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
    run_runner ~config:cfg_k2 ~is_screening_day:true ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
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
    run_runner ~config:cfg_k2 ~is_screening_day:true ~positions
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
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
    run_runner ~config:cfg_k2 ~is_screening_day:true ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
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
    run_runner ~config:cfg_k2 ~is_screening_day:true ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids
      ~current_date:_friday ()
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
    run_runner ~config:cfg_k2 ~is_screening_day:true ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
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
    run_runner ~config:cfg_k2 ~is_screening_day:true ~positions
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:95.0 ()) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
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
    run_runner ~config:cfg_k2 ~is_screening_day:true ~positions
      ~get_price:(fun _ -> None)
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
  in
  assert_that exits is_empty;
  (* Streak counter still advanced via observe_position. *)
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 2))

(* ------------------------------------------------------------------ *)
(* Backward-compat: hysteresis_weeks=1 + margin=0.0 fires on first read *)
(* ------------------------------------------------------------------ *)

let _cfg_k1 = { Stage3_force_exit.hysteresis_weeks = 1 }

let test_backward_compat_h1_margin0 _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  let bar = make_bar "2024-01-05" ~close:97.5 () in
  let exits =
    run_runner ~exit_margin_pct:0.0 ~prior_stage_ma_values:None ~config:_cfg_k1
      ~is_screening_day:true ~positions
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
  in
  assert_that exits
    (elements_are
       [
         field
           (fun (t : Trading_strategy.Position.transition) -> t.position_id)
           (equal_to "AAPL");
       ])

(* ------------------------------------------------------------------ *)
(* Margin filter: close above MA suppresses fire at h=1                 *)
(* ------------------------------------------------------------------ *)

let test_margin_close_above_ma_suppressed _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  let ma_values = Hashtbl.create (module String) in
  (* Close 100.0, MA 99.0 — close ABOVE MA by 1%; 2% margin requirement fails *)
  Hashtbl.set ma_values ~key:"AAPL" ~data:99.0;
  let bar = make_bar "2024-01-05" ~close:100.0 () in
  let exits =
    run_runner ~exit_margin_pct:0.02 ~prior_stage_ma_values:(Some ma_values)
      ~config:_cfg_k1 ~is_screening_day:true ~positions
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
  in
  assert_that exits is_empty;
  (* Streak still advances — only emission is gated. *)
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 1))

(* ------------------------------------------------------------------ *)
(* Margin filter: close marginally below MA still suppressed at 2%      *)
(* ------------------------------------------------------------------ *)

let test_margin_close_marginal_below_ma_suppressed _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  let ma_values = Hashtbl.create (module String) in
  (* Close 99.0, MA 100.0 — close 1% below MA; 2% margin still not met. *)
  Hashtbl.set ma_values ~key:"AAPL" ~data:100.0;
  let bar = make_bar "2024-01-05" ~close:99.0 () in
  let exits =
    run_runner ~exit_margin_pct:0.02 ~prior_stage_ma_values:(Some ma_values)
      ~config:_cfg_k1 ~is_screening_day:true ~positions
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
  in
  assert_that exits is_empty

(* ------------------------------------------------------------------ *)
(* Margin filter: deep below MA fires at 2% threshold                   *)
(* ------------------------------------------------------------------ *)

let test_margin_close_deep_below_ma_fires _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  let ma_values = Hashtbl.create (module String) in
  (* Close 95.0, MA 100.0 — close 5% below MA, well above 2% margin. *)
  Hashtbl.set ma_values ~key:"AAPL" ~data:100.0;
  let bar = make_bar "2024-01-05" ~close:95.0 () in
  let exits =
    run_runner ~exit_margin_pct:0.02 ~prior_stage_ma_values:(Some ma_values)
      ~config:_cfg_k1 ~is_screening_day:true ~positions
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
  in
  assert_that exits
    (elements_are
       [
         field
           (fun (t : Trading_strategy.Position.transition) -> t.position_id)
           (equal_to "AAPL");
       ])

(* ------------------------------------------------------------------ *)
(* Margin filter: symbol missing from ma table short-circuits as met    *)
(* ------------------------------------------------------------------ *)

let test_margin_missing_ma_short_circuits_to_met _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  let ma_values = Hashtbl.create (module String) in
  (* "AAPL" intentionally absent from ma_values — margin filter unavailable, *)
  (* so the runner falls back to hysteresis-only behaviour. *)
  let bar = make_bar "2024-01-05" ~close:100.0 () in
  let exits =
    run_runner ~exit_margin_pct:0.02 ~prior_stage_ma_values:(Some ma_values)
      ~config:_cfg_k1 ~is_screening_day:true ~positions
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
  in
  assert_that exits
    (elements_are
       [
         field
           (fun (t : Trading_strategy.Position.transition) -> t.position_id)
           (equal_to "AAPL");
       ])

(* ------------------------------------------------------------------ *)
(* Combined: confirmation (h=2) + margin (2%) — both gates apply        *)
(* ------------------------------------------------------------------ *)

let test_combined_confirmation_and_margin _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  (* prior streak = 1 — second Stage-3 read advances to 2 (hysteresis met) *)
  Hashtbl.set stage3_streaks ~key:"AAPL" ~data:1;
  let ma_values = Hashtbl.create (module String) in
  (* Margin satisfied: close 5% below MA. *)
  Hashtbl.set ma_values ~key:"AAPL" ~data:100.0;
  let bar = make_bar "2024-01-05" ~close:95.0 () in
  let exits =
    run_runner ~exit_margin_pct:0.02 ~prior_stage_ma_values:(Some ma_values)
      ~config:cfg_k2 ~is_screening_day:true ~positions
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
  in
  assert_that exits
    (elements_are
       [
         field
           (fun (t : Trading_strategy.Position.transition) -> t.position_id)
           (equal_to "AAPL");
       ]);
  (* Streak advanced from 1 to 2 — hysteresis threshold met on this tick. *)
  assert_that (Hashtbl.find stage3_streaks "AAPL") (is_some_and (equal_to 2))

(* ------------------------------------------------------------------ *)
(* Combined: confirmation met but margin fails → no fire                *)
(* ------------------------------------------------------------------ *)

let test_combined_confirmation_met_margin_fails _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage3;
  let stage3_streaks = Hashtbl.create (module String) in
  Hashtbl.set stage3_streaks ~key:"AAPL" ~data:1;
  let ma_values = Hashtbl.create (module String) in
  (* Close 100.0, MA 100.5 — close 0.5% below MA; 2% requirement fails. *)
  Hashtbl.set ma_values ~key:"AAPL" ~data:100.5;
  let bar = make_bar "2024-01-05" ~close:100.0 () in
  let exits =
    run_runner ~exit_margin_pct:0.02 ~prior_stage_ma_values:(Some ma_values)
      ~config:cfg_k2 ~is_screening_day:true ~positions
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~prior_stages ~stage3_streaks ~stop_exit_position_ids:String.Set.empty
      ~current_date:_friday ()
  in
  assert_that exits is_empty;
  (* Streak still advances — emission gated, counter unaffected. *)
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
         "backward-compat: hysteresis=1 + margin=0.0 fires on first read"
         >:: test_backward_compat_h1_margin0;
         "margin filter: close above MA at margin=2% suppresses fire"
         >:: test_margin_close_above_ma_suppressed;
         "margin filter: close marginally (1%) below MA at margin=2% suppressed"
         >:: test_margin_close_marginal_below_ma_suppressed;
         "margin filter: close deep (5%) below MA at margin=2% fires"
         >:: test_margin_close_deep_below_ma_fires;
         "margin filter: symbol absent from ma table → short-circuits to met"
         >:: test_margin_missing_ma_short_circuits_to_met;
         "combined: confirmation=2 + margin=2% both satisfied → fires"
         >:: test_combined_confirmation_and_margin;
         "combined: confirmation met but margin fails → no fire"
         >:: test_combined_confirmation_met_margin_fails;
       ]

let () = run_test_tt_main suite
