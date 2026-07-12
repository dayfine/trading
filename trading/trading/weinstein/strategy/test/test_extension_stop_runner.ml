(** Unit tests for {!Extension_stop_runner} — the strategy-side arm of the
    extension tail-insurance stop.

    Pins:
    - Default-off bit-identity: the no-op config leaves a held long untouched.
    - Fire: a long that ran to [2.0×] its WMA30 and then collapsed [25%] below
      the post-trigger peak weekly close emits an [extension_stop] TriggerExit
      at the current close.
    - Shakeout survival (width): the same run-up with only a ~-17% post-trigger
      dip is HELD under the [0.25] trail — the screen-pinned reason the build is
      wide.
    - Tighten-only (L2) / skip-set: a position already exiting this tick is
      skipped (an earlier structural exit always wins).
    - LONG-only: a short is never touched.
    - Off-cadence (non-screening-day) is a no-op. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Extension_stop = Weinstein_stops.Extension_stop

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date ~close =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* One weekly bar per consecutive Friday, starting 2020-01-03 (a Friday). Each
   Friday is a distinct ISO week, so [Bar_reader.weekly_bars_for] aggregates one
   bar per week. *)
let _friday0 = Date.of_string "2020-01-03"
let _week_date i = Date.add_days _friday0 (7 * i)

let _weekly_bars closes =
  List.mapi closes ~f:(fun i c -> make_bar (_week_date i) ~close:c)

(* A 34-week flat base at 20, then a spike to 2.0×+ its WMA, a higher peak, then
   a collapse 50% below the peak — an extension event that FIRES. Trigger week
   index 34, peak 35, collapse 36. *)
let _fire_closes = List.init 34 ~f:(fun _ -> 20.0) @ [ 100.0; 120.0; 60.0 ]

(* Same base + spike + peak, then only a ~-17% post-trigger dip (100 vs peak
   120), then the parabola resumes — HELD under a 0.25 trail. *)
let _shakeout_closes =
  List.init 34 ~f:(fun _ -> 20.0) @ [ 100.0; 120.0; 100.0; 140.0 ]

let _entry_idx = 30
let _entry_date = _week_date _entry_idx
let _armed_config = { Extension_stop.trigger_ratio = 2.0; trail_pct = 0.25 }
let _symbol = "EXT"

(** Build a Holding position for [_symbol] entered on [_entry_date]. Mirrors the
    helper in [test_liquidity_exit_runner.ml]. *)
let make_holding_pos ?(side = Trading_base.Types.Long) () =
  let make_trans kind =
    {
      Trading_strategy.Position.position_id = _symbol;
      date = _entry_date;
      kind;
    }
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
              symbol = _symbol;
              side;
              target_quantity = 10.0;
              entry_price = 20.0;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = 20.0 }))
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

let run ?(config = _armed_config) ?(is_screening_day = true)
    ?(skip_position_ids = String.Set.empty) ?(side = Trading_base.Types.Long)
    ~closes () =
  let bars = _weekly_bars closes in
  let last_bar = List.last_exn bars in
  let current_date = last_bar.Types.Daily_price.date in
  let pos = make_holding_pos ~side () in
  let positions = String.Map.singleton _symbol pos in
  let bar_reader = Bar_reader.of_in_memory_bars [ (_symbol, bars) ] in
  let get_price s = if String.equal s _symbol then Some last_bar else None in
  Extension_stop_runner.update ~config ~ma_period:30 ~is_screening_day
    ~positions ~bar_reader ~get_price ~skip_position_ids ~current_date

(* ------------------------------------------------------------------ *)
(* Default-off: no exit at the no-op default                           *)
(* ------------------------------------------------------------------ *)

let test_default_off_no_exit _ =
  let result =
    run ~config:Extension_stop.default_config ~closes:_fire_closes ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Fire: collapse 25% below the post-trigger peak emits extension_stop  *)
(* ------------------------------------------------------------------ *)

let test_collapse_fires_extension_stop _ =
  let result = run ~closes:_fire_closes () in
  (* Exit at the current (collapse) weekly close 60.0, tagged extension_stop. *)
  assert_that result
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_strategy.Position.transition) -> t.position_id)
               (equal_to _symbol);
             field
               (fun (t : Trading_strategy.Position.transition) -> t.kind)
               (matching
                  ~msg:"Expected TriggerExit StrategySignal extension_stop"
                  (function
                    | Trading_strategy.Position.TriggerExit
                        {
                          exit_reason =
                            Trading_strategy.Position.StrategySignal
                              { label; detail = _ };
                          exit_price;
                        } ->
                        Some (label, exit_price)
                    | _ -> None)
                  (all_of
                     [
                       field (fun (l, _) -> l) (equal_to "extension_stop");
                       field (fun (_, p) -> p) (float_equal 60.0);
                     ]));
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Shakeout survival: a shallow post-trigger dip is HELD (wide trail)   *)
(* ------------------------------------------------------------------ *)

let test_shakeout_survives_wide_trail _ =
  let result = run ~closes:_shakeout_closes () in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Tighten-only / skip-set: a position already exiting is skipped       *)
(* ------------------------------------------------------------------ *)

let test_skip_set_collision_no_op _ =
  let result =
    run
      ~skip_position_ids:(String.Set.singleton _symbol)
      ~closes:_fire_closes ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* LONG-only: a short is never touched                                  *)
(* ------------------------------------------------------------------ *)

let test_short_not_eligible _ =
  let result = run ~side:Trading_base.Types.Short ~closes:_fire_closes () in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Off-cadence: a non-screening-day call is a no-op                     *)
(* ------------------------------------------------------------------ *)

let test_off_cadence_no_op _ =
  let result = run ~is_screening_day:false ~closes:_fire_closes () in
  assert_that (List.length result) (equal_to 0)

let () =
  run_test_tt_main
    ("extension_stop_runner"
    >::: [
           "default-off: no exit" >:: test_default_off_no_exit;
           "collapse fires extension_stop"
           >:: test_collapse_fires_extension_stop;
           "shakeout survives wide (0.25) trail"
           >:: test_shakeout_survives_wide_trail;
           "skip-set collision is a no-op" >:: test_skip_set_collision_no_op;
           "short not eligible" >:: test_short_not_eligible;
           "off-cadence is a no-op" >:: test_off_cadence_no_op;
         ])
