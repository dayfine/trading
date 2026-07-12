open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vc = Post_run_validator.Validator_checks

(* ---- builders ---------------------------------------------------------- *)

let trade ?(side = "LONG") ?(exit_trigger = "") ?(stop_trigger_kind = "")
    ?(entry_price = 100.0) ?(exit_price = 100.0) ?(exit_date = "2020-06-01")
    ?(stop_initial_distance_pct = None) ~symbol ~entry_date () : Vt.trade_row =
  {
    symbol;
    side;
    entry_date = Date.of_string entry_date;
    exit_date = Date.of_string exit_date;
    entry_price;
    exit_price;
    quantity = 100.0;
    exit_trigger;
    stop_trigger_kind;
    stop_initial_distance_pct;
  }

let ctx ?(stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false })
    ?(macro_trend = Weinstein_types.Bullish)
    ?(ma_direction = Weinstein_types.Rising) ?(resistance_quality = None) () :
    Vt.entry_context =
  { stage; macro_trend; ma_direction; resistance_quality }

let audit_of assoc (row : Vt.trade_row) =
  List.Assoc.find assoc row.symbol ~equal:String.equal

let weekly pairs : Vt.bars =
  {
    weekly_dates = Array.of_list_map pairs ~f:(fun (d, _) -> Date.of_string d);
    weekly_closes = Array.of_list_map pairs ~f:(fun (_, c) -> c);
    daily = [||];
  }

let bars_of assoc sym = List.Assoc.find assoc sym ~equal:String.equal
let result ~id inputs = Vc.run_check ~id (inputs : Vt.inputs)

let violations_and_pass n_viol passed =
  all_of
    [
      field (fun (r : Vt.check_result) -> r.n_violations) (equal_to n_viol);
      field (fun (r : Vt.check_result) -> r.passed) (equal_to passed);
    ]

(* ---- V1: LONG entry must be Stage2 ------------------------------------- *)

let test_v1 _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"BAD" ~entry_date:"2020-01-03" ();
          trade ~symbol:"OK" ~entry_date:"2020-02-07" ();
        ];
      audit =
        audit_of
          [
            ("BAD", ctx ~stage:(Weinstein_types.Stage3 { weeks_topping = 2 }) ());
            ("OK", ctx ());
          ];
    }
  in
  assert_that (result ~id:"V1" inputs) (violations_and_pass 1 false)

(* ---- V2: no Bearish-macro LONG entry ----------------------------------- *)

let test_v2 _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"BEAR" ~entry_date:"2020-01-03" () ];
      audit = audit_of [ ("BEAR", ctx ~macro_trend:Weinstein_types.Bearish ()) ];
    }
  in
  assert_that (result ~id:"V2" inputs) (violations_and_pass 1 false)

(* ---- V5: exit_trigger vs stop_trigger_kind consistency ----------------- *)

let test_v5 _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          (* Strategy_signal label must be non_stop_exit, not intraday. *)
          trade ~symbol:"MISMATCH" ~entry_date:"2020-01-03"
            ~exit_trigger:"stage3_force_exit" ~stop_trigger_kind:"intraday" ();
          (* Stop-loss with gap_down is consistent. *)
          trade ~symbol:"OK" ~entry_date:"2020-02-07" ~exit_trigger:"stop_loss"
            ~stop_trigger_kind:"gap_down" ();
        ];
    }
  in
  assert_that (result ~id:"V5" inputs) (violations_and_pass 1 false)

(* ---- V6: rename-twin duplicate positions ------------------------------- *)

let test_v6 _ =
  let twin symbol =
    trade ~symbol ~entry_date:"2020-01-03" ~exit_date:"2020-05-01"
      ~entry_price:42.0 ~exit_price:37.0 ()
  in
  let inputs =
    { (Vt.empty_inputs ()) with trades = [ twin "NLS"; twin "BFX" ] }
  in
  assert_that (result ~id:"V6" inputs) (violations_and_pass 1 false)

let test_v6_no_twin _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"A" ~entry_date:"2020-01-03" ~entry_price:10.0 ();
          trade ~symbol:"B" ~entry_date:"2020-01-03" ~entry_price:20.0 ();
        ];
    }
  in
  assert_that (result ~id:"V6" inputs) (violations_and_pass 0 true)

(* ---- V9: entry beneath overhead supply --------------------------------- *)

let test_v9 _ =
  (* Prior top 115 sits +15% above the 100 entry (inside the 25% band). *)
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"OVH" ~entry_date:"2020-05-29" () ];
      bars =
        bars_of
          [ ("OVH", weekly [ ("2019-01-04", 115.0); ("2020-05-29", 100.0) ]) ];
    }
  in
  assert_that (result ~id:"V9" inputs) (violations_and_pass 1 false)

let test_v9_clean _ =
  (* All prior closes below entry: a clean breakout, no overhead. *)
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"CLR" ~entry_date:"2020-05-29" () ];
      bars =
        bars_of
          [ ("CLR", weekly [ ("2019-01-04", 80.0); ("2020-05-29", 100.0) ]) ];
    }
  in
  assert_that (result ~id:"V9" inputs) (violations_and_pass 0 true)

(* ---- V10: entry-week vertical spike ------------------------------------ *)

let spike_bars closes =
  weekly
    (List.zip_exn
       [ "2020-05-01"; "2020-05-08"; "2020-05-15"; "2020-05-22"; "2020-05-29" ]
       closes)

let test_v10 _ =
  (* Entry week 100 is +100% above the 4-weeks-ago 50 (> 60% spike). *)
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"SPK" ~entry_date:"2020-05-29" () ];
      bars = bars_of [ ("SPK", spike_bars [ 50.0; 50.0; 50.0; 50.0; 100.0 ]) ];
    }
  in
  assert_that (result ~id:"V10" inputs) (violations_and_pass 1 false)

let test_v10_calm _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"CLM" ~entry_date:"2020-05-29" () ];
      bars = bars_of [ ("CLM", spike_bars [ 90.0; 90.0; 90.0; 90.0; 100.0 ]) ];
    }
  in
  assert_that (result ~id:"V10" inputs) (violations_and_pass 0 true)

(* ---- V11: stop distance bounds ----------------------------------------- *)

let test_v11 _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"WIDE" ~entry_date:"2020-01-03"
            ~stop_initial_distance_pct:(Some 0.55) ();
          trade ~symbol:"OK" ~entry_date:"2020-02-07"
            ~stop_initial_distance_pct:(Some 0.08) ();
        ];
    }
  in
  assert_that (result ~id:"V11" inputs) (violations_and_pass 1 false)

(* ---- severity + validate wiring ---------------------------------------- *)

let test_severity_default _ =
  assert_that
    (result ~id:"V1" (Vt.empty_inputs ()))
    (field (fun (r : Vt.check_result) -> r.severity) (equal_to Vt.Invariant))

let test_validate_runs_all _ =
  let report = Vc.validate (Vt.empty_inputs ()) in
  assert_that report.checks (size_is (List.length Vc.all_check_ids))

let suite =
  "post_run_validator"
  >::: [
         "v1_stage" >:: test_v1;
         "v2_macro" >:: test_v2;
         "v5_trigger_consistency" >:: test_v5;
         "v6_twin" >:: test_v6;
         "v6_no_twin" >:: test_v6_no_twin;
         "v9_overhead" >:: test_v9;
         "v9_clean" >:: test_v9_clean;
         "v10_spike" >:: test_v10;
         "v10_calm" >:: test_v10_calm;
         "v11_stop_bounds" >:: test_v11;
         "severity_default" >:: test_severity_default;
         "validate_runs_all" >:: test_validate_runs_all;
       ]

let () = run_test_tt_main suite
