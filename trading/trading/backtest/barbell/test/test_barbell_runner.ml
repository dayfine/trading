open Core
open OUnit2
open Matchers

let d s = Date.of_string s

let floor_leg () : Barbell.Barbell_runner.leg_result =
  {
    name = "floor";
    equity_curve =
      [
        (d "2020-01-01", 100.0); (d "2020-01-02", 110.0); (d "2020-01-03", 121.0);
      ];
  }

let engine_leg () : Barbell.Barbell_runner.leg_result =
  {
    name = "engine";
    equity_curve =
      [
        (d "2020-01-01", 100.0); (d "2020-01-02", 90.0); (d "2020-01-03", 108.0);
      ];
  }

let cfg ~floor_weight : Barbell.Barbell_config.t =
  { enable = true; floor_weight; rebalance_weeks = 1 }

(* Backward-compat: floor_weight = 0.0 => the blended NAV is exactly the engine
   leg's own growth normalised (100 -> 90 -> 108 = [1.0; 0.9; 1.08]), so a
   no-op-weight barbell reproduces the pure-engine run. *)
let test_pure_engine_backward_compat _ =
  let result =
    Barbell.Barbell_runner.run ~config:(cfg ~floor_weight:0.0) ~floor_leg
      ~engine_leg
  in
  assert_that
    (List.map result.blend.nav_curve ~f:snd)
    (elements_are [ float_equal 1.0; float_equal 0.9; float_equal 1.08 ])

(* The runner threads both legs through to the result so callers can inspect each
   sleeve's own curve alongside the blend. *)
let test_run_retains_both_legs _ =
  let result =
    Barbell.Barbell_runner.run ~config:(cfg ~floor_weight:0.3) ~floor_leg
      ~engine_leg
  in
  assert_that result
    (all_of
       [
         field (fun r -> r.Barbell.Barbell_runner.floor.name) (equal_to "floor");
         field
           (fun r -> r.Barbell.Barbell_runner.engine.name)
           (equal_to "engine");
         field
           (fun r -> r.Barbell.Barbell_runner.blend.metrics.n_points)
           (equal_to 3);
       ])

(* An invalid config raises before any leg runs. *)
let test_invalid_config_raises _ =
  assert_raises
    (Invalid_argument "Barbell_runner.run: rebalance_weeks must be >= 1: 0")
    (fun () ->
      Barbell.Barbell_runner.run
        ~config:{ enable = true; floor_weight = 0.3; rebalance_weeks = 0 }
        ~floor_leg ~engine_leg)

(* write_equity_curve emits the canonical date,portfolio_value CSV from the
   blended NAV path. *)
let test_write_equity_curve test_ctxt =
  let result =
    Barbell.Barbell_runner.run ~config:(cfg ~floor_weight:0.0) ~floor_leg
      ~engine_leg
  in
  let dir = OUnit2.bracket_tmpdir test_ctxt in
  Barbell.Barbell_runner.write_equity_curve result ~output_dir:dir;
  let lines = In_channel.read_lines (dir ^ "/equity_curve.csv") in
  assert_that (List.hd_exn lines) (equal_to "date,portfolio_value")

let suite =
  "barbell_runner"
  >::: [
         "pure_engine_backward_compat" >:: test_pure_engine_backward_compat;
         "run_retains_both_legs" >:: test_run_retains_both_legs;
         "invalid_config_raises" >:: test_invalid_config_raises;
         "write_equity_curve" >:: test_write_equity_curve;
       ]

let () = run_test_tt_main suite
