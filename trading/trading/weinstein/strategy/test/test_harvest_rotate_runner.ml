open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date ~close =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

let late_stage2 = Weinstein_types.Stage2 { weeks_advancing = 12; late = true }
let early_stage2 = Weinstein_types.Stage2 { weeks_advancing = 5; late = false }
let stage1 = Weinstein_types.Stage1 { weeks_in_base = 4 }
let stage3 = Weinstein_types.Stage3 { weeks_topping = 1 }
let stage4 = Weinstein_types.Stage4 { weeks_declining = 2 }
let friday = Date.of_string "2024-01-05" (* Friday *)
let monday = Date.of_string "2024-01-08" (* Monday *)

(** Build a Holding {!Position.t} for [ticker] with [qty] shares at [entry].
    Mirrors the helper in [test_late_stage2_stop_runner.ml]. [qty] is exposed so
    the trimmed [target_quantity = qty *. harvest_fraction] can be asserted. *)
let make_holding_pos ?(side = Trading_base.Types.Long) ?(qty = 10.0) ticker
    ~entry ~date =
  let make_trans kind =
    { Trading_strategy.Position.position_id = ticker; date; kind }
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
              target_quantity = qty;
              entry_price = entry;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = qty; fill_price = entry }))
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

(** Convenience wrapper: single-symbol position + stage + price, returns the
    runner's transitions. [harvest_fraction] defaults to 0.5 (sell half). *)
let run_single ?(harvest_fraction = 0.5) ?(is_screening_day = true)
    ?(qty = 10.0) ~stage ~close ~current_date ?(side = Trading_base.Types.Long)
    () =
  let pos = make_holding_pos ~side ~qty "AAPL" ~entry:100.0 ~date:friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage;
  Harvest_rotate_runner.update ~harvest_fraction ~is_screening_day ~positions
    ~get_price:(get_price_of [ ("AAPL", make_bar "2024-01-05" ~close) ])
    ~prior_stages ~current_date

(** Matcher for a [TriggerPartialExit] transition trimming [symbol] by
    [expected_qty] at [expected_price]. *)
let trims symbol ~expected_qty ~expected_price =
  all_of
    [
      field
        (fun (t : Trading_strategy.Position.transition) -> t.position_id)
        (equal_to symbol);
      matching ~msg:"Expected TriggerPartialExit"
        (function
          | Trading_strategy.Position.
              {
                kind = TriggerPartialExit { target_quantity; exit_price; _ };
                _;
              } ->
              Some (target_quantity, exit_price)
          | _ -> None)
        (all_of
           [
             field (fun (q, _) -> q) (float_equal expected_qty);
             field (fun (_, p) -> p) (float_equal expected_price);
           ]);
    ]

(* ------------------------------------------------------------------ *)
(* Test 1 — late Stage 2 long: trim qty*harvest_fraction at close       *)
(* ------------------------------------------------------------------ *)

(** A held late-Stage-2 long is trimmed by [harvest_fraction] at the current
    close. With qty=10, close=120, harvest_fraction=0.5 the trim is 5.0 shares
    at price 120. *)
let test_late_stage2_trims_half _ =
  let transitions =
    run_single ~harvest_fraction:0.5 ~qty:10.0 ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that transitions
    (elements_are [ trims "AAPL" ~expected_qty:5.0 ~expected_price:120.0 ])

(* ------------------------------------------------------------------ *)
(* Test 1b — harvest_fraction plumbs from config (0.33 vs 0.5)          *)
(* ------------------------------------------------------------------ *)

(** A different [harvest_fraction] produces a proportionally different trim:
    0.33 * 10 = 3.3 shares. *)
let test_fraction_plumbs_through _ =
  let transitions =
    run_single ~harvest_fraction:0.33 ~qty:10.0 ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that transitions
    (elements_are
       [ trims "AAPL" ~expected_qty:(10.0 *. 0.33) ~expected_price:120.0 ])

(* ------------------------------------------------------------------ *)
(* Test 1c — fraction >= 1.0 trims the whole position (full rotate)     *)
(* ------------------------------------------------------------------ *)

(** A [harvest_fraction] of 1.0 trims the entire position (10 shares) — a full
    rotate out of the topping name. *)
let test_full_rotate _ =
  let transitions =
    run_single ~harvest_fraction:1.0 ~qty:10.0 ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that transitions
    (elements_are [ trims "AAPL" ~expected_qty:10.0 ~expected_price:120.0 ])

(* ------------------------------------------------------------------ *)
(* Test 2 — control: non-late / other stages produce no transition      *)
(* ------------------------------------------------------------------ *)

let test_early_stage2_no_trim _ =
  let transitions =
    run_single ~stage:early_stage2 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

let test_stage1_no_trim _ =
  let transitions =
    run_single ~stage:stage1 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

let test_stage3_no_trim _ =
  let transitions =
    run_single ~stage:stage3 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

let test_stage4_no_trim _ =
  let transitions =
    run_single ~stage:stage4 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

(* ------------------------------------------------------------------ *)
(* Test 3 — disabled path: non-positive fraction is a no-op             *)
(* ------------------------------------------------------------------ *)

(** [harvest_fraction <= 0.0] is the no-op (nothing to trim) — the bit-identical
    disabled value path (the caller default-off flag short-circuits before this,
    but the runner itself must also no-op on a non-positive fraction). *)
let test_zero_fraction_no_op _ =
  let transitions =
    run_single ~harvest_fraction:0.0 ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that transitions is_empty

(* ------------------------------------------------------------------ *)
(* Test 4 — cadence + side + empty controls                             *)
(* ------------------------------------------------------------------ *)

let test_non_friday_no_op _ =
  let transitions =
    run_single ~is_screening_day:false ~stage:late_stage2 ~close:120.0
      ~current_date:monday ()
  in
  assert_that transitions is_empty

let test_short_side_no_trim _ =
  let transitions =
    run_single ~side:Trading_base.Types.Short ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that transitions is_empty

let test_empty_positions_no_op _ =
  let transitions =
    Harvest_rotate_runner.update ~harvest_fraction:0.5 ~is_screening_day:true
      ~positions:String.Map.empty ~get_price:(get_price_of [])
      ~prior_stages:(Hashtbl.create (module String))
      ~current_date:friday
  in
  assert_that transitions is_empty

let test_missing_stage_no_op _ =
  let pos = make_holding_pos "AAPL" ~entry:100.0 ~date:friday in
  let positions = String.Map.singleton "AAPL" pos in
  let transitions =
    Harvest_rotate_runner.update ~harvest_fraction:0.5 ~is_screening_day:true
      ~positions
      ~get_price:(get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:120.0) ])
      ~prior_stages:(Hashtbl.create (module String))
      ~current_date:friday
  in
  assert_that transitions is_empty

let test_missing_price_no_op _ =
  let pos = make_holding_pos "AAPL" ~entry:100.0 ~date:friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:late_stage2;
  let transitions =
    Harvest_rotate_runner.update ~harvest_fraction:0.5 ~is_screening_day:true
      ~positions ~get_price:(get_price_of []) ~prior_stages ~current_date:friday
  in
  assert_that transitions is_empty

let suite =
  "harvest_rotate_runner"
  >::: [
         "late_stage2_trims_half" >:: test_late_stage2_trims_half;
         "fraction_plumbs_through" >:: test_fraction_plumbs_through;
         "full_rotate" >:: test_full_rotate;
         "early_stage2_no_trim" >:: test_early_stage2_no_trim;
         "stage1_no_trim" >:: test_stage1_no_trim;
         "stage3_no_trim" >:: test_stage3_no_trim;
         "stage4_no_trim" >:: test_stage4_no_trim;
         "zero_fraction_no_op" >:: test_zero_fraction_no_op;
         "non_friday_no_op" >:: test_non_friday_no_op;
         "short_side_no_trim" >:: test_short_side_no_trim;
         "empty_positions_no_op" >:: test_empty_positions_no_op;
         "missing_stage_no_op" >:: test_missing_stage_no_op;
         "missing_price_no_op" >:: test_missing_price_no_op;
       ]

let () = run_test_tt_main suite
